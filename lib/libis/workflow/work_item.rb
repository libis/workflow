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
      attr_accessor :status_log
      attr_accessor :summary

      def initialize
        self.parent = nil
        self.items = []
        self.options = {}
        self.properties = {}
        self.status_log = []
        self.summary = {}
      end

      protected

      def add_status_log(info)
        # noinspection RubyResolve
        self.status_log << info
        self.status_log.last
      end

    end

  end
end
