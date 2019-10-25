# frozen_string_literal: true

module Libis
  module Workflow
    module Base
      module TaskStatus

        ## Assumes that a StatusLog implementation class is set in Config[:status_log]
        #

        # @return [Libis::Workflow::Status] status entry or nil if not found
        def last_item_status(item)
          item = nil unless item.is_a? Libis::Workflow::WorkItem
          Config[:status_log].find_last(task: self, item: item)
        end

        # @return [Libis::Workflow::Status] newly created status entry
        def set_item_status(status:, item:, progress: nil, max: nil)
          item = nil unless item.is_a? Libis::Workflow::WorkItem
          Config[:status_log].set_status(status: status, task: self, item: item, progress: progress, max: max)
        end

        # @return [Libis::Workflow::Status] updated or created status entry
        def status_progress(item:, progress: nil, max: nil)
          entry = last_item_status(item)
          entry&.update_status({ progress: progress || entry.progress + 1, max: max }.compact) ||
              set_item_status(status: :started, item: item, progress: progress, max: max)
        end

        # Get last known status symbol for a given task and item
        # @return [Symbol] the status code
        def item_status(item)
          entry = last_item_status(item)
          entry&.status_sym || StatusEnum.keys.first
        end

        # Get last known status text for a given task
        # @return [String] the status text
        def item_status_txt(item)
          entry = last_item_status(item)
          entry&.status_txt || StatusEnum.values.first
        end

        # Gets the last known status label of the object.
        # @return [String] status label ( = task name + status )
        def item_status_label(item)
          "#{task}#{item_status(item).to_s.camelize}"
        end

        # Check status of the object.
        # @return [Boolean] true if the object status matches
        def item_status_equals(item:, status:)
          compare_item_status(item: item, status: status).zero?
        end

        # Compare status with current status of the object.
        # @return [Integer] 1, 0 or -1 depending on which status is higher in rank
        def compare_item_status(item:, status:)
          StatusEnum.to_int(item_status(item)) <=> StatusEnum.to_int(status)
        end

      end
    end
  end
end
