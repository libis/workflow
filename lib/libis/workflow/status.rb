module Libis
  module Workflow
    module Status

      STATUS = {
          NOT_STARTED: 0,
          STARTED: 1,
          DONE: 2,
          ASYNC_WAIT: 3,
          ASYNC_HALT: 4,
          FAILED: 5
      }

      # Changes the status of the object. The status changed is logged in the status_log with the current timestamp.
      #
      # @param [Array] x Array with status and task
      def status=(x)
        s, task = x
        self.add_status_log(task: task, status: s)
        self.save
      end

      # Get last known status symbol for a given task
      #
      # @param [String] task task name to check item status for
      # @return [Symbol] the status code
      def status(task = nil)
        entry = status_entry(task)
        status_symbol(entry[:status]) rescue :NOT_STARTED
      end

      # Gets the last known status label of the object.
      #
      # @param [String] task name of task to get the status for
      # @return [String] status label ( = task name + status )
      def status_label(task = nil)
        entry = self.status_entry(task)
        "#{entry[:task] rescue nil}#{entry[:status].capitalize rescue nil}"
      end

      # Check status of the object.
      #
      # @param [Symbol] state status to look for
      # @param [String] task name of task whose status to check
      # @return [Boolean] true if the object status matches
      def check_status(state, task = nil)
        self.status(task) == state
      end

      # Compare status with current status of the object.
      #
      # @param [Symbol] state
      # @return [Integer] 1, 0 or -1 depnding on which
      def compare_status(state, task = nil)
        STATUS[self.status(task)] <=> STATUS[state]
      end

      protected

      # Get last known status entry for a given task
      #
      # @param [String] task task name to check item status for
      # @return [Hash] the status entry
      def status_entry(task = nil)
        return self.status_log.last if task.blank?
        self.status_log.select { |entry| entry[:task] == task }.last
      end

      # Convert String, Symbol or Integer to correct symbol for the status.
      # If the input value is nil, the fist status entry is returned.
      #
      # @param [String|Symbol|Integer] x string, symbol or integer for status code.
      # @return [Symbol] the corresponding STATUS symbol
      def status_symbol(x)
        return STATUS.key(x) if x.is_a?(Integer)
        return x if STATUS.has_key?(x)
        x = x.to_s.upcase.to_sym
        STATUS.has_key?(x) ? x : nil
      end

    end
  end
end
