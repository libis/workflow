require_relative 'task'

module Libis
  module Workflow

    # noinspection RubyTooManyMethodsInspection
    class TaskGroup < Libis::Workflow::Task

      parameter abort_on_failure: true,
                description: 'Stop processing tasks if one task fails.'

      attr_accessor :tasks

      def initialize(parent, cfg = {})
        self.tasks = []
        super parent, cfg
      end

      def <<(task)
        self.tasks << task
        task.parent = self
      end

      def apply_options(opts)
        super opts
        self.tasks.each do |task|
          task.apply_options opts
        end
      end

      protected

      def process(item)

        return unless check_processing_subtasks

        tasks = subtasks
        return unless tasks.size > 0

        status_count = Hash.new(0)
        item.status_progress(self.namepath, 0, tasks.count)
        continue = true
        tasks.each_with_index do |task, i|
          unless task.parameter(:run_always)
            next unless continue
            if item.status(task.namepath) == :DONE && item.get_run.action == :retry
              debug 'Retry: skipping task %s because it has finished successfully.', item, task.namepath
              next
            end
          end
          info 'Running subtask (%d/%d): %s', item, i+1, tasks.size, task.name
          new_item = task.run item
          item = new_item if new_item.is_a?(Libis::Workflow::Base::WorkItem)
          item.status_progress(self.namepath, i+1)
          item_status = item.status(task.namepath)
          status_count[item_status] += 1
          continue = false if !task.parameter(:run_always) && parameter(:abort_on_failure) && item_status != :DONE
        end

        substatus_check(status_count, item, 'task')

        info item.status_text(self.namepath).capitalize, item
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

    end

  end
end
