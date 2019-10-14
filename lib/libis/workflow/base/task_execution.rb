# frozen_string_literal: true

module Libis
  module Workflow
    module Base
      module TaskExecution

        def action
          run.action
        end

        def action=(value)
          run.action = value
        end

        def execute(item, opts = {})
          return nil unless check_item_type [Job, WorkItem], item
          return item if action == :abort && !parameter(:run_always)

          item = execution_loop(item)

          self.action = :abort unless item
          item
        rescue WorkflowError => e
          error e.message, item
          set_status status: :failed, item: item
        rescue WorkflowAbort => e
          set_status status: :failed, item: item
          raise e if parent
        rescue StandardError => e
          set_status status: :failed, item: item
          fatal_error "Exception occured: #{e.message}", item
          debug e.backtrace.join("\n")
        end

        def pre_process(_item)
          true
          # optional implementation
        end

        def post_process(_item)
          # optional implementation
        end

        protected

        def execution_loop(item)
          (parameter(:retry_count).abs + 1).times do
            new_item = process_item(item)
            item = new_item if new_item.is_a?(Libis::Workflow::WorkItem)

            case status(item: item)
            when :done, :reverted
              return item
            when :failed, :async_halt
              self.action = :abort
              return item
            when :async_wait
              sleep(parameter(:retry_interval))
            else
              warn 'Something went terribly wrong, retrying ...'
            end
          end
        end

        def process_item(item)
          @item_skipper = false

          return item if status(item: item) == :done && !parameter(:run_always)

          pre_process(item)

          if @item_skipper
            run_subitems(item) if parameter(:recursive)
          else
            set_status status: :started, item: item
            self.processing_item = item
            process item
            item = processing_item
            run_subitems(item) if parameter(:recursive)
            set_status status: :done, item: item if check_status(:started, item: item)
          end

          post_process item

          item
        end

        def run_subitems(parent_item)
          return unless check_processing_subitems

          items = subitems(parent_item)
          return if items.empty?

          status_count = Hash.new(0)
          status_progress(item: parent_item, progress: 0, max: items.count)
          items.each_with_index do |item, i|
            debug 'Processing subitem (%d/%d): %s', parent_item, i + 1, items.size, item.to_s
            # new_item = item

            begin
              new_item = process_item(item)
            rescue Libis::WorkflowError => e
              set_status(status: :failed, item: item)
              error 'Error processing subitem (%d/%d): %s', item, i + 1, items.size, e.message
              break if parameter(:abort_recursion_on_failure)
            rescue Libis::WorkflowAbort => e
              fatal_error 'Fatal error processing subitem (%d/%d): %s', item, i + 1, items.size, e.message
              set_status(status: :failed, item: item)
              break
            rescue StandardError => e
              set_status(status: :failed, item: item)
              raise Libis::WorkflowAbort, "#{e.message} @ #{e.backtrace.first}"
            else
              item = new_item if new_item.is_a?(Libis::Workflow::WorkItem)
              status_progress(item: parent_item, progress: i + 1)
            ensure
              # noinspection RubyScope
              item_status = status(item: item)
              # noinspection RubyScope
              status_count[item_status] += 1
              break if parameter(:abort_recursion_on_failure) && item_status != :done
            end
          end

          # noinspection RubyScope
          debug '%d of %d subitems passed', parent_item, status_count[:done], items.size
          substatus_check(status_count, parent_item, 'item')
        end

        def capture_cmd(cmd, *opts)
          out = StringIO.new
          err = StringIO.new
          $stdout = out
          $stderr = err
          status = system cmd, *opts
          [status, out.string, err.string]
        ensure
          $stdout = STDOUT
          $stderr = STDERR
        end

      end
    end
  end
end
