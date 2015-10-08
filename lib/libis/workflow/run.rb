# encoding: utf-8

require 'libis/workflow/config'
require 'libis/workflow/workflow'

require 'libis/workflow/base/run'
require 'libis/workflow/work_item'

module Libis
  module Workflow

    class Run < ::Libis::Workflow::WorkItem
      include ::Libis::Workflow::Base::Run

      attr_accessor :start_date, :workflow

      def initialize
        @start_date = Time.now
        @workflow = nil
        super
      end

    end

  end
end