# frozen_string_literal: true

require_relative 'task'

module Libis::Workflow
  # noinspection RubyTooManyMethodsInspection
  class TaskGroup < Task
    parameter abort_on_failure: true,
              description: 'Stop processing tasks if one task fails.'

    attr_accessor :tasks

    def initialize(cfg = {})
      @tasks = []
      super cfg
      add_tasks cfg[:tasks]
    end

    # Create all subtasks
    #
    # The configuration array contains the task hierarchy as individual hashes containing:
    # - class: [String] task class name; if not present a TaskGroup will be created and name is then required.
    # - name: [String] name of the task; required when class is not present.
    # - parameters: [Hash] parameter names and values to configure on the task.
    # - tasks: [Array] list of subtask configurations (recursive); subtasks are not allowed when class is present.
    #
    # @param [Array] config list of task configurations to instantiate
    def add_tasks(config = [])
      config.each do |task|
        task[:class] ||= 'Libis::Worlflow::TaskGroup'
        obj = task[:class].to_s.constantize.send(:new, task)
        self << obj
      end
    end

    def add_task(task)
      tasks << task
      task.parent = self
    end

    alias << add_task

    def apply_options(opts)
      super opts
      tasks.each do |task|
        task.apply_options opts
      end
    end

    protected

    def process(item)
      return unless check_processing_subtasks

      tasks = subtasks
      return if tasks.empty?

      status_count = Hash.new(0)
      item.status_progress(namepath, 0, tasks.count)
      continue = true
      tasks.each_with_index do |task, i|
        unless task.parameter(:run_always)
          next unless continue

          if item.status(task.namepath) == :DONE && item.get_run.action == :retry
            debug 'Retry: skipping task %s because it has finished successfully.', item, task.namepath
            next
          end
        end
        info 'Running subtask (%d/%d): %s', item, i + 1, tasks.size, task.name
        new_item = task.run item
        item = new_item if new_item.is_a?(Libis::Workflow::WorkItem)
        item.status_progress(namepath, i + 1)
        item_status = item.status(task.namepath)
        status_count[item_status] += 1
        continue = false if parameter(:abort_on_failure) && item_status != :DONE
      end

      substatus_check(status_count, item, 'task')

      info item.status_text(namepath).capitalize, item
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
