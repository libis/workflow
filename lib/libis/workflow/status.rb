module Libis
  module Workflow
    module Status

      protected

      STATUS = {
          NOT_STARTED: 0,
          STARTED: 1,
          ASYNC_WAIT: 2,
          DONE: 3,
          ASYNC_HALT: 4,
          FAILED: 5
      }

      STATUS_TEXT = [
          'not started',
          'started',
          'waiting for running async process',
          'done',
          'waiting for halted async process',
          'failed'
      ]

      public

      # Changes the status of the object. The status changed is logged in the status_log with the current timestamp.
      #
      # @param [String] task namepath of the task
      # @param [Symbol] status status to set
      def set_status(task, status)
        task = task.namepath if task.is_a?(Libis::Workflow::Task)
        log_entry = self.status_entry(task)
        if log_entry.nil? || STATUS[status_symbol(log_entry['status'])] > STATUS[status_symbol(status)]
          log_entry = self.add_status_log('task' => task, 'status' => status, 'created' => DateTime.now)
        end
        log_entry['status'] = status
        log_entry['updated'] = DateTime.now
        self.save!
      end

      # Get last known status symbol for a given task
      #
      # @param [String] task task name to check item status for
      # @return [Symbol] the status code
      def status(task = nil)
        entry = self.status_entry(task)
        status_symbol(entry['status']) rescue :NOT_STARTED
      end

      # Get last known status text for a given task
      #
      # @param [String] task task name to check item status for
      # @return [Symbol] the status code
      def status_text(task = nil)
        entry = self.status_entry(task)
        status_string(entry['status']) rescue STATUS_TEXT.first
      end

      # Gets the last known status label of the object.
      #
      # @param [String] task name of task to get the status for
      # @return [String] status label ( = task name + status )
      def status_label(task = nil)
        entry = self.status_entry(task)
        "#{entry['task'] rescue nil}#{entry['status'].capitalize rescue nil}"
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
      # @return [Integer] 1, 0 or -1 depending on which status is higher in rank
      def compare_status(state, task = nil)
        STATUS[self.status(task)] <=> STATUS[state]
      end

      # Update the progress of the working task
      # @param [String] task namepath of the task
      # @param [Integer] progress progress indicator (as <progress> of <max> or as % if <max> not set). Default: 0
      # @param [Integer] max max count.
      def status_progress(task, progress = nil, max = nil)
        log_entry = self.status_entry(task)
        log_entry ||= self.add_status_log('task' => task, 'status' => :STARTED, 'created' => DateTime.now)
        log_entry['progress'] = progress ? progress : (log_entry['progress'] || 0) + 1
        log_entry['max'] = max if max
        log_entry['updated'] = DateTime.now
        self.save!
      end

      protected

      # Get last known status entry for a given task
      #
      # @param [String] task task name to check item status for
      # @return [Hash] the status entry
      def status_entry(task = nil)
        task = task.namepath if task.is_a?(Libis::Workflow::Task)
        return self.status_log.last if task.blank?
        self.status_log.select { |entry| entry['task'] == task }.last
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

      def status_string(x)
        return STATUS_TEXT[x] if x.is_a?(Integer)
        return STATUS_TEXT[STATUS[x]] if STATUS.has_key?(x)
        x = x.to_s.upcase.to_sym
        STATUS.has_key?(x) ? STATUS_TEXT[STATUS[x]] : 'unknown status'
      end

    end
  end
end
