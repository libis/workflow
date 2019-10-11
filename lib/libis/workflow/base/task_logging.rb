# frozen_string_literal: true

module Libis::Workflow
  module TaskLogging
    def message(severity, msg, *args)
      set_application(namepath)
      item = begin
        workitem
      rescue StandardError
        nil
      end
      item = args.shift if !args.empty? && args[0].is_a?(::Libis::Workflow::Base::WorkItem)
      subject = begin
        item.namepath
      rescue StandardError
        nil
      end
      subject ||= begin
        item.name
      rescue StandardError
        nil
      end
      subject ||= begin
        item.to_s
      rescue StandardError
        nil
      end
      set_subject(subject)
      super(severity, msg, *args)
    end

    def logger
      (parent || get_run).logger
    end

  end
end