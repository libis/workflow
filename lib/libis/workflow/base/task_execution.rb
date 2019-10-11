module Libis::Workflow::Base
  module TaskExecution
    attr_accessor :action, :workitem

    def execute(item)
      return unless check_item_type [Job, WorkItem], item

      return item if action == :failed && !parameter(:run_always)

      begin
        ((parameter(:retry_count).abs + 1).times do
          new_item = process_item(item)
          item = new_item if new_item.is_a?(Libis::Workflow::WorkItem)

          # noinspection RubyScope
          case status(item: item)
          when :DONE
            # self.action = :run
            return item
          when :ASYNC_WAIT
            self.action = :retry
          when :ASYNC_HALT
            break
          when :FAILED
            break
          else
            return item
          end

          self.action = :retry

          sleep(parameter(:retry_interval))
        end

        self.action = :failed

        item

        rescue WorkflowError => e
        error e.message, item
        set_status item, :FAILED
        rescue WorkflowAbort => e
        set_status item, :FAILED
        raise e if parent
        rescue StandardError => e
        set_status item, :FAILED
        fatal_error "Exception occured: #{e.message}", item
        debug e.backtrace.join("\n")
        ensure
        item.save!
      end
    end

    def pre_process(_)
      true
      # optional implementation
    end

    def post_process(_)
      # optional implementation
    end

    protected

    def run_item(item)
      @item_skipper = false

      return item if item.status(namepath) == :DONE && !parameter(:run_always)

      pre_process(item)

      if @item_skipper
        run_subitems(item) if parameter(:recursive)
      else
        set_status item, :STARTED
        self.processing_item = item
        process item
        item = processing_item
        run_subitems(item) if parameter(:recursive)
        set_status item, :DONE if item.check_status(:STARTED, namepath)
      end

      post_process item

      item
    end

    protected

    def run_subitems(parent_item)
      return unless check_processing_subitems

      items = subitems(parent_item)
      return if items.empty?

      status_count = Hash.new(0)
      parent_item.status_progress(namepath, 0, items.count)
      items.each_with_index do |item, i|
        debug 'Processing subitem (%d/%d): %s', parent_item, i + 1, items.size, item.to_s
        new_item = item

        begin
          new_item = run_item(item)
        rescue Libis::WorkflowError => e
          item.set_status(namepath, :FAILED)
          error 'Error processing subitem (%d/%d): %s', item, i + 1, items.size, e.message
          break if parameter(:abort_recursion_on_failure)
        rescue Libis::WorkflowAbort => e
          fatal_error 'Fatal error processing subitem (%d/%d): %s', item, i + 1, items.size, e.message
          item.set_status(namepath, :FAILED)
          break
        rescue StandardError => e
          item.set_status(namepath, :FAILED)
          raise Libis::WorkflowAbort, "#{e.message} @ #{e.backtrace.first}"
        else
          item = new_item if new_item.is_a?(Libis::Workflow::WorkItem)
          parent_item.status_progress(namepath, i + 1)
        ensure
          # noinspection RubyScope
          item_status = item.status(namepath)
          # noinspection RubyScope
          status_count[item_status] += 1
          break if parameter(:abort_recursion_on_failure) && item_status != :DONE
        end
      end

      # noinspection RubyScope
      debug '%d of %d subitems passed', parent_item, status_count[:DONE], items.size
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