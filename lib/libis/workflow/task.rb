# encoding: utf-8
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

      attr_accessor :parent, :name, :workitem

      parameter quiet: false, description: 'Prevemt generating log output.'
      parameter recursive: false, description: 'Run the task on all subitems recursively.'
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
            return if item.check_status(:DONE, self.namepath)
          when :failed
            return
          else
        end

        (parameter(:retry_count)+1).times do

          run_item(item)

          case item.status(self.namepath)
            when :DONE
              self.action = :run
              return
            when :ASYNC_WAIT
              self.action = :retry
            when :ASYNC_HALT
              break
            when :FAILED
              break
            else
              return
          end

          self.action = :retry

          sleep(parameter(:retry_interval))

        end

        item.get_run.action = :failed

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

      ensure
        item.save

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
        o.key_symbols_to_strings!

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
        item = self.workitem
        item = args.shift if args.size > 0 and args[0].is_a?(::Libis::Workflow::Base::WorkItem)
        return unless super(severity, msg, *args)
        if item
          subject = nil
          begin
            subject = item.to_s
            subject = item.name
            subject = item.namepath
          rescue
            # do nothing
          end
          self.set_subject(subject)
          item.log_message(
              severity, msg.is_a?(Integer) ? {id: msg} : {text: (msg.to_s rescue '')}.merge(task: taskname), *args
          )
        end
      end

      def logger
        (self.parent || self.get_run).logger
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

      def run_item(item)
        @item_skipper = false

        pre_process(item)

        set_status item, :STARTED

        self.process item unless @item_skipper

        run_subitems(item) if parameter(:recursive)

        update_status item, :DONE

        post_process item
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
        items.each_with_index do |item, i|
          debug 'Processing subitem (%d/%d): %s', parent_item, i+1, items.size, item.to_s
          run_item item
          status[item.status(self.namepath)] += 1
        end

        debug '%d of %d subitems passed', parent_item, status[:DONE], items.size
        substatus_check(status, parent_item, 'item')
      end

      def substatus_check(status, item, task_or_item)
        if (failed = status[:FAILED]) > 0
          error "%d sub#{task_or_item}(s) failed", item, failed
          update_status(item, :FAILED)
        end

        if (halted = status[:ASYNC_HALT]) > 0
          warn "%d sub#{task_or_item}(s) halted in async process", item, halted
          update_status(item, :ASYNC_HALT)
        end

        if (waiting = status[:ASYNC_WAIT]) > 0
          info "waiting for %d sub#{task_or_item}(s) in async process", item, waiting
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

      def update_status(item, state)
        return nil unless item.compare_status(state, self.namepath) < 0
        set_status(item, state)
      end

      def set_status(item, state)
        item.status = to_status(state)
        state
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

      def subtasks
        self.tasks
      end

      def subitems(item = nil)
        (item || self.workitem).get_items
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
