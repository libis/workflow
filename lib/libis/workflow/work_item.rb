# encoding: utf-8
require 'libis/tools/extend/hash'
require 'libis/workflow/base/work_item'

module Libis
  module Workflow

    # In-memory implementation of ::Libis::Workflow::Base::WorkItem
    class WorkItem
      include ::Libis::Workflow::Base::WorkItem

      attr_accessor :parent
      attr_accessor :items
      attr_accessor :options, :properties
      attr_accessor :log_history, :status_log
      attr_accessor :summary

      def initialize
        self.parent = nil
        self.items = []
        self.options = {}
        self.properties = {}
        self.log_history = []
        self.status_log = []
        self.summary = {}
      end

      protected

      def add_log_entry(msg)
        # noinspection RubyResolve
        self.log_history << msg.merge(c_at: ::Time.now)
      end

      def add_status_log(message, tasklist = nil)
        # noinspection RubyResolve
        self.status_log << {
            timestamp: ::Time.now,
            tasklist: tasklist,
            status: message
        }.cleanup
      end

    end

  end
end
