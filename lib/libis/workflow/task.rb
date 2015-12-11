# encoding: utf-8
require 'backports/rails/hash'
require 'backports/rails/string'

require 'libis/tools/parameter'
require 'libis/tools/extend/hash'

require 'libis/workflow'

module Libis
  module Workflow

    # noinspection RubyTooManyMethodsInspection
    class Task
      include ::Libis::Workflow::Base::Logger
      include ::Libis::Tools::ParameterContainer

      attr_accessor :parent, :name, :workitem, :tasks

      parameter quiet: false, description: 'Prevemt generating log output.'
      parameter abort_on_error: false, description: 'Stop all tasks when an error occurs.'
      parameter always_run: false, description: 'Run this task, even if the item failed a previous task.'
      parameter subitems: false, description: 'Do not process the given item, but only the subitems.'
      parameter recursive: false, description: 'Run the task on all subitems recursively.'
      parameter retry_count: 0, description: 'Number of times to retry the task.'
      parameter retry_interval: 10, description: 'Number of seconds to wait between retries.'

      def self.task_classes
        ObjectSpace.each_object(::Class).select { |klass| klass < self }
      end

      def initialize(parent, cfg = {})
        @subitems_stopper = false
        @subtasks_stopper = false
        self.parent = parent
        self.tasks = []
        configure cfg
      end

      def <<(task)
        self.tasks << task
      end

      def run(item)
        check_item_type ::Libis::Workflow::Base::WorkItem, item
        return unless item.check_status(:DONE, self.namepath) || parameter(:always_run)
        run_once(item)
      end

      def retry(item)
        check_item_type ::Libis::Workflow::Base::WorkItem, item
        return if item.check_status(:DONE, self.namepath)
        run_once(item)
      end

      def run_once(item)

        (parameter(:retry_count)+1).times do

          if parameter(:subitems)
            begin
              set_status item, :STARTED
              run_subitems item
              update_status item, :DONE

            rescue WorkflowError => e
              error e.message, item
              update_status item, :FAILED

            rescue WorkflowAbort => e
              update_status item, :FAILED
              raise e if parent

            rescue ::Exception => e
              update_status item, :FAILED
              fatal "Exception occured: #{e.message}", item
              debug e.backtrace.join("\n")
            end
          else
            run_item(item)
          end

          item.save

          return if item.check_status(:DONE, self.namepath)

          sleep(parameter(:retry_interval))

        end

      end

      def run_item(item)

        begin

          self.workitem = item

          process_item item

        rescue WorkflowError => e
          error e.message, item
          update_status item, :FAILED

        rescue WorkflowAbort => e
          update_status item, :FAILED
          raise e if parent

        rescue ::Exception => e
          update_status item, :FAILED
          fatal "Exception occured: #{e.message}", item
          debug e.backtrace.join("\n")
        end

      end

      def names
        (self.parent.names rescue Array.new).push(name).compact
      end

      def namepath;
        self.names.join('/');
      end

      def apply_options(opts)
        o = {}
        o.merge!(opts[self.class.to_s] || {})
        o.merge!(opts[self.name] || opts[self.names.join('/')] || {})
        o.key_strings_to_symbols! recursive: true

        if o and o.is_a? Hash
          default_values.each do |name, _|
            next unless o.key?(name)
            next if o[name].nil?
            paramdef = get_parameter_definition name
            value = paramdef.parse(o[name])
            self.parameter(name, value)
          end
        end

        self.tasks.each do |task|
          task.apply_options opts
        end
      end

      protected

      def configure(cfg)
        self.name = cfg[:name] || (cfg[:class] || self.class).to_s.split('::').last
        (cfg[:options] || {}).merge(
            cfg.reject { |k, _| [:options, :name, :class].include? k.to_sym }
        ).symbolize_keys.each do |k, v|
          self.parameter(k, v)
        end
      end

      def process_item(item)
        @item_skipper = false
        pre_process(item)
        unless @item_skipper
          set_status item, :STARTED
          process item
        end
        run_subitems(item) if parameter(:recursive)
        unless @item_skipper
          run_subtasks item
          update_status item, :DONE
        end
        post_process item
      end

      def process(item)
        # needs implementation unless there are subtasks
        raise RuntimeError, 'Should be overwritten' if self.tasks.empty?
      end

      def pre_process(_)
        true
        # optional implementation
      end

      def post_process(_)
        # optional implementation
      end

      def run_subitems(parent_item)
        return unless check_processing_subitems
        items = subitems parent_item
        status = Hash.new(0)
        items.each_with_index do |item, i|
          debug 'Processing subitem (%d/%d): %s', parent_item, i+1, items.count, item.to_s
          run_item item
          status[item.status] += 1
          if item.check_status(:FAILED) && parameter(:abort_on_error)
            error 'Aborting ...', parent_item
            raise WorkflowAbort.new "Aborting: task #{name} failed on #{item}"
          end
        end

        return unless items.count > 0

        substatus_check(status, parent_item, 'item')
      end

      def run_subtasks(item)

        return unless check_processing_subtasks

        tasks = subtasks item
        status = Hash.new(0)

        tasks.each_with_index do |task, i|
          debug 'Running subtask (%d/%d): %s', item, i+1, tasks.count, task.name
          task.run item
          status[item.status(task.namepath)] += 1
          if item.check_status(:FAILED, task.namepath) && task.parameter(:abort_on_error)
            error 'Aborting ...', item
            raise WorkflowAbort.new "Aborting: task #{task.name} failed on #{item}"
          end
        end

        substatus_check(status, item, 'task')
      end

      def substatus_check(status, item, task_or_item)
        if (failed = status[:FAILED] > 0)
          warn "%d sub#{task_or_item}(s) failed", item, failed
          update_status(item, :FAILED)
        end

        if (halted = status[:ASYNC_HALT] > 0)
          warn "%d sub#{task_or_item}(s) halted in async process", item, halted
          update_status(item, :ASYNC_HALT)
        end

        if (waiting = status[:ASYNC_WAIT] > 0)
          warn "waiting for %d sub#{task_or_item}(s) in async process", item, waiting
          update_status(item, :ASYNC_WAIT)
        end

        update_status(item, :DONE)
      end

      def capture_cmd(cmd, *opts)
        out = StringIO.new
        err = StringIO.new
        $stdout = out
        $stderr = err
        status = system cmd, *opts
        return [status, out.string, err.string]
      ensure
        $stdout = STDOUT
        $stderr = STDERR
      end

      def get_root_item(item = nil)
        (item || self.workitem).root
      end

      def get_work_dir(item = nil)
        get_root_item(item).work_dir
      end

      def stop_processing_subitems
        @subitems_stopper = true if parameter(:recursive)
      end

      def check_processing_subitems
        if @subitems_stopper
          @subitems_stopper = false
          return false
        end
        true
      end

      def stop_processing_subtasks
        @subtasks_stopper= true
      end

      def check_processing_subtasks
        if @subtasks_stopper
          @subtasks_stopper = false
          return false
        end
        true
      end

      def skip_processing_item
        @item_skipper = true
      end

      def set_status(item, state)
        item.status = to_status(state)
        state
      end

      def update_status(item, state)
        return nil if item.compare_status(state, self.namepath) > 0
        set_status(item, state)
      end

      def to_status(state)
        [state, self.namepath]
      end

      def check_item_type(klass, item = nil)
        item ||= self.workitem
        unless item.is_a? klass.to_s.constantize
          raise WorkflowError, "Workitem is of wrong type : #{item.class} - expected #{klass.to_s}"
        end
      end

      def item_type?(klass, item = nil)
        item ||= self.workitem
        item.is_a? klass.to_s.constantize
      end

      private

      def subtasks(_ = nil)
        self.tasks
      end

      def subitems(item = nil)
        (item || workitem).items
      end

      def default_values
        self.class.default_values
      end

      def self.default_values
        parameter_defs.inject({}) do |hash, parameter|
          hash[parameter.first] = parameter.last[:default]
          hash
        end
      end

    end

  end
end
