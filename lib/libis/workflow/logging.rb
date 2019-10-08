# frozen_string_literal: true

module Libis
  module Workflow

    module Logging

      # Add a structured message to the log history. The message text can be submitted as an integer or text. If an
      # integer is submitted, it will be used to look up the text in the MessageRegistry. The message text will be
      # passed to the % operator with the args parameter. If that failes (e.g. because the format string is not correct)
      # the args value is appended to the message.
      #
      # @param [Symbol] severity
      # @param [Hash] msg should contain message text as :id or :text and the hierarchical name of the task as :task
      # @param [Array] args string format values
      def log_message(severity, msg, *args)
        # Prepare info from msg struct for use with string substitution
        message_id, message_text = if msg[:id]
                                     [msg[:id], MessageRegistry.instance.get_message(msg[:id])]
                                   elsif msg[:text]
                                     [0, msg[:text]]
                                   else
                                     [0, '']
                                   end
        task = msg[:task] || ''
        message_text = (message_text % args rescue "#{message_text} - #{args}")

        self.add_log severity: severity, id: message_id.to_i, text: message_text, task: task
      end

      # Helper function for the WorkItems to add a log entry to the log_history.
      #
      # The supplied message structure is expected to contain the following fields:
      # - :severity : ::Logger::Severity value
      # - :id : optional message id
      # - :text : message text
      # - :task : list of tasks names (task hierarchy) that submits the message
      #
      # @param [Hash] message
      def add_log(message = {})
        msg = message_struct(message)
        # noinspection RubyResolve
        add_log_entry(msg)
        self.save!
      end

      def <=(message = {})
        self.add_log(message)
      end

      protected

      # create and return a proper message structure
      # @param [Hash] opts
      def message_struct(opts = {})
        opts.reverse_merge!(severity: :info, code: nil, text: '')
        {
            severity: ::Logging::levelify(opts[:severity]).upcase,
            task: opts[:task],
            code: opts[:code],
            message: opts[:text]
        }.cleanup
      end

    end

  end
end