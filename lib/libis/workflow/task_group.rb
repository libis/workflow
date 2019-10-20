# frozen_string_literal: true

require_relative 'task'

module Libis
  module Workflow
    # noinspection RubyTooManyMethodsInspection
    class TaskGroup < Task

      parameter abort_on_failure: true,
                description: 'Stop processing tasks if one task fails.'

      attr_accessor :tasks, :name

      def initialize(cfg = {})
        @tasks = []
        @name = cfg[:name]
        super cfg
      end

      def add_task(task)
        tasks << task
        task.parent = self
      end

      alias << add_task

      protected

      def process(item)
        return unless check_processing_subtasks

        tasks = subtasks
        return if tasks.empty?

        status_count = Hash.new(0)
        status_progress(item: item, progress: 0, max: tasks.count)
        continue = true
        tasks.each_with_index do |task, i|
          unless task.parameter(:run_always)
            next unless continue

            if item.last_status(task) == :done && run.action == 'retry'
              debug 'Retry: skipping task %s because it has finished successfully.', item, task.namepath
              next
            end
          end
          info 'Running subtask (%d/%d): %s', item, i + 1, tasks.size, task.name
          new_item = task.execute item
          item = new_item if new_item.is_a?(Libis::Workflow::WorkItem)
          status_progress(item: item, progress: i + 1)
          item_status = task.item_status(item)
          status_count[item_status] += 1
          continue = false if parameter(:abort_on_failure) && Base::StatusEnum.failed?(item_status)
        end

        substatus_check(status_count, item, 'task')

        info item_status_txt(item).capitalize, item
      end

      def stop_processing_subtasks
        @subtasks_stopper = true
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
