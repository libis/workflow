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

        status = Hash.new(0)
        tasks.each_with_index do |task, i|
          info 'Running subtask (%d/%d): %s', item, i+1, tasks.size, task.name
          task.run item
          status[item.status(task.namepath)] += 1
          break if parameter(:abort_on_failure) && item.status(task.namepath) != :DONE
        end

        substatus_check(status, item, 'task')
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
