# frozen_string_literal: true

module Libis::Workflow::Base
  module TaskHierarchy
    attr_accessor :parent, :name

    def <<(_task)
      raise Libis::WorkflowError, "Processing task '#{namepath}' is not allowed to have subtasks."
    end

    def names
      (parent&.names || []).push(name).compact
    end

    def namepath
      names.join('/')
    end

    def substatus_check(status_count, item, task_or_item)
      item_status = :DONE

      if (waiting = status_count[:ASYNC_WAIT]) > 0
        info "waiting for %d sub#{task_or_item}(s) in async process", item, waiting
        item_status = :ASYNC_WAIT
      end

      if (halted = status_count[:ASYNC_HALT]) > 0
        warn "%d sub#{task_or_item}(s) halted in async process", item, halted
        item_status = :ASYNC_HALT
      end

      if (failed = status_count[:FAILED]) > 0
        error "%d sub#{task_or_item}(s) failed", item, failed
        item_status = :FAILED
      end

      set_status(item, item_status)
    end


  end
end
