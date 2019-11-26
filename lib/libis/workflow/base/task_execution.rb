# frozen_string_literal: true

module Libis
  module Workflow
    module Base
      module TaskExecution

        def action
          parent&.action.to_s
        end

        def action=(value)
          parent&.action = value.to_s
        end

        def execute(item, *args)
          return item if action == 'abort' && !run_always

          item = execution_loop(item, *args)

          self.action = 'abort' unless item
          item
        rescue WorkflowError => e
          error e.message, item
          set_item_status status: :failed, item: item
        rescue WorkflowAbort => e
          set_item_status status: :failed, item: item
          raise e if parent
        rescue StandardError => e
          set_item_status status: :failed, item: item
          fatal_error "Exception occured: #{e.message}", item
          debug e.backtrace.join("\n")
        end

        def pre_process(_item, *_args)
          true
          # optional implementation
        end

        def post_process(_item, *_args)
          # optional implementation
        end

        protected

        def execution_loop(item, *args)
          (retry_count.abs + 1).times do
            new_item = process_item(item, *args)
            item = new_item if check_item_type item, raise_on_error: false

            case item_status(item)
            when :not_started
              return item
            when :done, :reverted
              return item
            when :failed, :async_halt
              self.action = 'abort'
              return item
            when :async_wait
              sleep(retry_interval)
            else
              warn 'Something went terribly wrong, retrying ...'
            end
          end
          item
        end

        def process_item(item, *args)

          return item if item.last_status(self) == :done && !run_always

          if pre_process(item, *args)
            set_item_status status: :started, item: item
            process item, *args
          end

          run_subitems(item, *args) if recursive
          set_item_status status: :done, item: item if item_status_equals(item: item, status: :started)

          post_process item, *args

          item
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
