# frozen_string_literal: true

module Libis
  module Workflow
    module StatusLog

      ### Methods that need implementation in the including class
      # getter accessors for:
      # - status
      # class methods:
      # - create_status(...)
      # - find_last(...)
      # - find_all(...)
      # instance methods:
      # - update_status(...)

      module Classmethods

        def set_status(status: nil, task:, item: nil, progress: nil, max: nil)
          item = nil unless item.is_a? Libis::Workflow::WorkItem
          entry = send(:find_last, task: task, item: item)
          values = { status: status, task: task, item: item, progress: progress, max: max }.compact
          return send(:create_status, values) if entry.nil?
          return send(:create_status, values) if Base::StatusEnum.to_int(status) <
                                                 Base::StatusEnum.to_int(entry.send(:status))

          entry.send(:update_status, values.slice(:status, :progress, :max))
        end

        def sanitize(run: nil, task: nil, item: nil)
          run ||= task.run if task
          task = task.namepath if task
          item = nil unless item.is_a? Libis::Workflow::WorkItem
          [run, task, item]
        end

      end

      def self.included(base)
        base.extend Classmethods
      end

      def status_sym
        Base::StatusEnum.to_sym(send(:status))
      end

      def status_txt
        Base::StatusEnum.to_str(send(:status))
      end

    end
  end
end
