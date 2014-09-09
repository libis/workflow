# encoding: utf-8

require 'backports/rails/hash'
require 'backports/rails/string'

module LIBIS
  module Workflow

    class Task

      attr_reader :parent, :name, :action, :options, :workitem

      def initialize(parent, config = {})
        set_parent parent
        set_config config
      end

      def run(item)

        @workitem = item

        check_item_type WorkItem, item

        return if item.failed? unless options[:allways_run]

        item.status = to_status :started
        debug 'Started'

        process
        options[:per_item] ? process_subitems : process_subtasks
        post_process

        unless item.failed?
          debug 'Completed'
          item.set_status to_status :done
        end

      rescue WorkflowError => e
        error e.message
        item.set_status(to_status(:failed))

      rescue WorkflowAbort => e
        item.set_status(to_status(:failed))
        raise e if parent

      rescue ::Exception => e
        fatal 'Exception occured: %s', e.message
        debug e.backtrace.join("\n")
        workitem.status = to_status :failed

      end

      protected

      def set_parent(p)
        @parent = p
      end



      def default_options
        {abort_on_error: false, always_run: false, per_item: false}
      end

      def process
        # needs implementation unless there are subtasks
        raise RuntimeError, 'Should be overwritten' if @task_config.empty?
      end

      def post_process
        # optional implementation
      end

      def process_subitems
        items = subitems
        failed = 0
        items.each_with_index do |item, i|
          debug 'Processing subitem (%d/%d): %s', i+1, items.count, item
          run_subtasks item
          failed += 1 if item.failed?
        end
        if failed > 0
          warn '%d item(s) failed', failed
          if failed == items.count
            error 'All child items have failed'
            workitem.status = to_status :failed
          end
        end
        debug '%d of %d items passed', items.count - failed, items.count if items.count > 0
      end

      def process_subtasks
        tasks = subtasks
        tasks.each_with_index do |task, i|
          debug 'Running subtask (%d/%d): %s', i+1, tasks.count, task.name
          task.run_subitems workitem
        end
      end

      def get_root_item
        root_item = workitem
        root_item = root_item.parent until root_item.parent.nil?
        root_item
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
          debug 'Processing subitem (%d/%d): %s', parent_item, i+1, items.count, item
          run item
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

      def set_config(cfg)
        set_name(cfg[:name] || cfg[:class] || self.class.name)
        @task_config = cfg[:tasks] || []

        @action = cfg[:action] || :START

        temp = cfg.dup
        temp.delete :options
        temp.delete :tasks

        @options = default_options.merge(cfg[:options] || {}).merge(temp).symbolize_keys!
      end

      def set_name(name)
        @name = name
      end

      private

      def subtasks(item = nil)
        item ||= workitem
        @task_config.map do |t|
          task_class = Task
          task_class = t[:class].constantize if t[:class]
          task_instance = task_class.new self, t.symbolize_keys!
          (item.failed? and not task_instance.options[:always_run]) ? nil : task_instance
        end.compact
      end

      def subitems(item = nil)
        item ||= workitem
        items = item.items
        unless self.options[:always_run]
          items = items.reject { |i| i.failed? }
        end
        items
      end
    end

  end
end
