# frozen_string_literal: true
require 'singleton'

module Libis
  module Workflow
    class MessageRegistry
      include Singleton

      def initialize
        @message_db = {}
      end

      def register_message(id, message)
        @message_db[id] = message
      end

      def get_message(id)
        @message_db[id]
      end

      def self.register_message(id, message)
        self.instance.register_message id, message
      end

      def self.get_message(id)
        self.instance.get_message id
      end

    end
  end
end
