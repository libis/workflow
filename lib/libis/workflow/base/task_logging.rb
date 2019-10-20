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
          add_log_entry(severity, item, msg, *args)
          super(severity, msg, *args)
        end

        def add_log_entry(_severity, _item, _msg, *_args); end

        def logger
          (parent || run).logger
        end

      end
    end
  end
end
