# frozen_string_literal: true

module Libis
  module Workflow
    module Base
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
          final_item_status = :done

          if (waiting = status_count[:async_wait]).positive?
            info "waiting for %d sub#{task_or_item}(s) in async process", item, waiting
            final_item_status = :async_wait
          end

          if (halted = status_count[:async_halt]).positive?
            warn "%d sub#{task_or_item}(s) halted in async process", item, halted
            final_item_status = :async_halt
          end

          if (failed = status_count[:failed]).positive?
            error "%d sub#{task_or_item}(s) failed", item, failed
            final_item_status = :failed
          end

          set_item_status(item: item, status: final_item_status)
        end

        private

        def subtasks
          tasks
        end

        def subitems(item)
          item.item_list
        end

      end
    end
  end
end
