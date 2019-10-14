# frozen_string_literal: true

module Libis
  module Workflow
    module Base
      module TaskLogging

        def message(severity, msg, *args)
          set_application(namepath)
          item = args.shift if args&.first&.is_a?(WorkItem) || args&.first&.is_a?(Job)
          subject = item&.namepath || item&.name || item&.to_s || nil
          set_subject(subject)
          super(severity, msg, *args)
        end

        def logger
          (parent || run).logger
        end

      end
    end
  end
end
