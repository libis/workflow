# encoding: utf-8
require 'backports/rails/hash'
require 'backports/rails/string'

require 'libis/workflow'

module LIBIS
  module Workflow

    class Task
      include Base::Logger

      attr_accessor :parent, :name, :options, :workitem, :tasks

      def initialize(parent, cfg = {})
        self.parent = parent
        self.tasks = []
        configure cfg
      end

      def <<(task)
        self.tasks << task
      end

      def run(item)

        check_item_type WorkItem, item

        return if item.failed? unless options[:allways_run]

        options[:subitems] ? run_subitems(item) : run_item(item)

      end

      def run_item(item)

        begin

          self.workitem = item

          item.status = to_status :started
          debug 'Started'

          process
          run_subtasks item
          post_process

          if item.failed?
            debug 'Failed'
            item.status = to_status :failed
          else
            debug 'Completed'
            item.status = to_status :done
          end

        rescue WorkflowError => e
          error e.message
          item.status = to_status :failed

        rescue WorkflowAbort => e
          item.status = to_status :failed
          raise e if parent

        rescue ::Exception => e
          fatal 'Exception occured: %s', e.message
          debug e.backtrace.join("\n")
          workitem.status = to_status :failed
        end

        run_subitems(item) if options[:recursive]

      end

      protected

      def default_options
        {abort_on_error: false, always_run: false, subitems: false, recursive: false}
      end

      def process
        # needs implementation unless there are subtasks
        raise RuntimeError, 'Should be overwritten' if self.tasks.empty?
      end

      def post_process
        # optional implementation
      end

      def get_root_item
        self.workitem.root
      end

      def get_work_dir
        get_root_item.get_work_dir
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

      def run_subitems(parent_item)
        items = subitems parent_item
        failed = passed = 0
        items.each_with_index do |item, i|
          debug 'Processing subitem (%d/%d): %s', parent_item, i+1, items.count, item.to_s
          run_item item
          if item.failed?
            failed += 1
            if options[:abort_on_error]
              error 'Aborting ...'
              raise WorkflowAbort.new "Aborting: task #{name} failed on #{item}"
            end
          else
            passed += 1
          end
        end
        if failed > 0
          warn '%d item(s) failed', failed
          if failed == items.count
            error 'All child items have failed'
            parent_item.status = to_status :failed
          end
        end
        debug '%d of %d items passed', parent_item, passed, items.count if items.count > 0
      end

      def run_subtasks(item)
        tasks = subtasks item
        tasks.each_with_index do |task, i|
          debug 'Running subtask (%d/%d): %s', item, i+1, tasks.count, task.name
          task.run item
          if item.failed?
            if task.options[:abort_on_error]
              error 'Aborting ...'
              raise WorkflowAbort.new "Aborting: task #{task.name} failed on #{item}"
            end
            return
          end
        end
      end

      def configure(cfg)
        self.name = cfg[:name] || cfg[:class] || self.class.name
        self.options =
            self.default_options.merge(
                cfg[:options] || {}
            ).merge(
                cfg.reject { |k, _| [:options].include? k.to_sym }
            ).symbolize_keys!
      end

      def to_status(text)
        ((self.name || self.parent.name + 'Worker') + text.to_s.capitalize).to_sym
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

      def names
        (self.parent.names rescue Array.new).push(name).compact
      end

      private

      def subtasks(item = nil)
        self.tasks.map do |task|
          ((item || self.workitem).failed? and not task.options[:always_run]) ? nil : task
        end.compact
      end

      def subitems(item = nil)
        items = (item || workitem).items
        return items if self.options[:always_run]
        items.reject { |i| i.failed? }
      end
    end

  end
end
