require 'backports/rails/hash'
require 'backports/rails/string'

require 'libis/tools/parameter'
require 'libis/tools/extend/hash'
require 'libis/tools/logger'

require 'libis/workflow'

module Libis
  module Workflow

    # noinspection RubyTooManyMethodsInspection
    class Task
      include ::Libis::Tools::Logger
      include ::Libis::Tools::ParameterContainer

      attr_accessor :parent, :name, :workitem, :processing_item

      parameter recursive: false, description: 'Run the task on all subitems recursively.'
      parameter abort_recursion_on_failure: false, description: 'Stop processing items recursively if one item fails.'
      parameter retry_count: 0, description: 'Number of times to retry the task if waiting for another process.'
      parameter retry_interval: 10, description: 'Number of seconds to wait between retries.'

      def self.task_classes
        ObjectSpace.each_object(::Class).select { |klass| klass < self }
      end

      def initialize(parent, cfg = {})
        @subitems_stopper = false
        @subtasks_stopper = false
        self.parent = parent
        configure cfg
      end

      def <<(task)
        raise Libis::WorkflowError, "Processing task '#{self.namepath}' is not allowed to have subtasks."
      end

      # @param [Libis::Workflow::Base::WorkItem] item
      def run(item)
        check_item_type ::Libis::Workflow::Base::WorkItem, item
        self.workitem = item

        case self.action
          when :retry
            if item.check_status(:DONE, self.namepath)
              debug 'Retry: skipping task %s because it has finished successfully.', item, self.namepath
              return item
            end
          when :failed
            return item
          else
        end

        (parameter(:retry_count)+1).times do

          item = run_item(item)

          case item.status(self.namepath)
            when :DONE
              self.action = :run
              return item
            when :ASYNC_WAIT
              self.action = :retry
            when :ASYNC_HALT
              break
            when :FAILED
              break
            else
              return item
          end

          self.action = :retry

          sleep(parameter(:retry_interval))

        end

        item.get_run.action = :failed

      rescue WorkflowError => e
        error e.message, item
        set_status item, :FAILED

      rescue WorkflowAbort => e
        set_status item, :FAILED
        raise e if parent

      rescue ::Exception => e
        set_status item, :FAILED
        fatal "Exception occured: #{e.message}", item
        debug e.backtrace.join("\n")

      ensure
        item.save!

        item

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

        if o and o.is_a? Hash
          default_values.each do |name, _|
            next unless o.key?(name.to_s)
            next if o[name.to_s].nil?
            paramdef = get_parameter_definition name.to_sym
            value = paramdef.parse(o[name.to_s])
            self.parameter(name.to_sym, value)
          end
        end
      end

      def message(severity, msg, *args)
        taskname = self.namepath rescue nil
        self.set_application(taskname)
        item = self.workitem rescue nil
        item = args.shift if args.size > 0 and args[0].is_a?(::Libis::Workflow::Base::WorkItem)
        subject = item.namepath rescue nil
        subject ||= item.name rescue nil
        subject ||= item.to_s rescue nil
        self.set_subject(subject)
        super(severity, msg, *args)
      end

      def logger
        (self.parent || self.get_run).logger
      end

      protected

      def configure(cfg)
        self.name = cfg['name'] || (cfg['class'] || self.class).to_s.split('::').last
        (cfg['options'] || {}).merge(
            cfg.reject { |k, _| %w(options name class).include? k }
        ).symbolize_keys.each do |k, v|
          self.parameter(k, v)
        end
      end

      def run_item(item)
        @item_skipper = false

        return item if item.status(self.namepath) == :DONE

        pre_process(item)

        unless @item_skipper
          set_status item, :STARTED
          self.processing_item = item
          self.process item
          item = self.processing_item
          run_subitems(item) if parameter(:recursive)
          set_status item, :DONE if item.check_status(:STARTED, self.namepath)
        else
          run_subitems(item) if parameter(:recursive)
        end

        post_process item

        item
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

        items = subitems(parent_item)
        return unless items.size > 0

        status = Hash.new(0)
        parent_item.status_progress(self.namepath, 0, items.count)
        items.each_with_index do |item, i|
          debug 'Processing subitem (%d/%d): %s', parent_item, i+1, items.size, item.to_s
          item = run_item item
          parent_item.status_progress(self.namepath, i+1)
          item_status = item.status(self.namepath)
          status[item_status] += 1
          break if parameter(:abort_recursion_on_failure) && item_status != :DONE
        end

        debug '%d of %d subitems passed', parent_item, status[:DONE], items.size
        substatus_check(status, parent_item, 'item')
      end

      def substatus_check(status, item, task_or_item)
        item_status = :DONE

        if (waiting = status[:ASYNC_WAIT]) > 0
          info "waiting for %d sub#{task_or_item}(s) in async process", item, waiting
          item_status = :ASYNC_WAIT
        end

        if (halted = status[:ASYNC_HALT]) > 0
          warn "%d sub#{task_or_item}(s) halted in async process", item, halted
          item_status = :ASYNC_HALT
        end

        if (failed = status[:FAILED]) > 0
          error "%d sub#{task_or_item}(s) failed", item, failed
          item_status = :FAILED
        end

        set_status(item, item_status)
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

      def action=(action)
        self.get_run.action = action
      end

      def action
        self.get_run.action
      end

      def get_run(item = nil)
        get_root_item(item).get_run
      end

      def get_root_item(item = nil)
        (item || self.workitem).get_root
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

      def skip_processing_item
        @item_skipper = true
      end

      def set_status(item, state)
        item.set_status self.namepath, state
        state
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

      def subtasks
        self.tasks
      end

      def subitems(item = nil)
        (item || self.workitem).get_item_list
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
