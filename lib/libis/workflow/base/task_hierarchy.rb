# frozen_string_literal: true

module Libis
  module Workflow
    module Base
      module TaskHierarchy

        attr_accessor :parent, :name, :recursion_blocker

        def stop_recursion
          @recursion_blocker = true if recursive
        end

        def check_recursion
          if @recursion_blocker
            @recursion_blocker = false
            return false
          end
          true
        end

        def run_subitems(parent_item, *args)
          return unless check_recursion

          items = subitems(parent_item)
          return if items.empty?

          status_count = Hash.new(0)
          status_progress(item: parent_item, progress: 0, max: items.count)
          items.each_with_index do |item, i|
            debug 'Processing subitem (%d/%d): %s', parent_item, i + 1, items.size, item.to_s

            begin
              new_item = process_item(item, *args)
              item = new_item if new_item.is_a?(Libis::Workflow::WorkItem)
            rescue Libis::WorkflowError => e
              set_item_status(status: :failed, item: item)
              error 'Error processing subitem (%d/%d): %s', parent_item, i + 1, items.size, e.message
            rescue Libis::WorkflowAbort => e
              fatal_error 'Fatal error processing subitem (%d/%d): %s', parent_item, i + 1, items.size, e.message
              set_item_status(status: :failed, item: item)
              break
            rescue StandardError => e
              fatal_error 'Unexpected error processing subitem (%d/%d): %s', parent_item, i + 1, items.size, e.message
              set_item_status(status: :failed, item: item)
              raise Libis::WorkflowAbort, "#{e.message} @ #{e.backtrace.first}"
            ensure
              item_status = item_status(item)
              status_count[item_status] += 1
              break if abort_on_failure && item_status != :done
              status_progress(item: parent_item, progress: i + 1)
            end
          end

          debug '%d of %d subitems passed', parent_item, status_count[:done], items.size
          substatus_check(status_count, parent_item, 'item')
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

        def subitems(item)
          item.item_list
        end

      end
    end
  end
end
