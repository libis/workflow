module Libis
  module Workflow
    module Action

      RUN = 0
      CONTINUE = 1
      RETRY = 2
      ALWAYS_RUN = 3
      FAILED = 4

      def next_success_action(action)
        case action
          when :run, :continue, :retry, :always_run
            :always_run
          when :failed
            :failed
          else
            :failed
        end
      end

    end
  end
end
