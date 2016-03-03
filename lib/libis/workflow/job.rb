# encoding: utf-8

require 'libis/workflow/base/job'
require 'libis/workflow/workflow'
require 'libis/workflow/run'

module Libis
  module Workflow

    class Job
      include ::Libis::Workflow::Base::Job

      attr_accessor :name, :description, :workflow, :run_object, :input

      def initialize
        @name = ''
        @description = ''
        @input = Hash.new
        @workflow = ::Libis::Workflow::Workflow.new
        @run_object = ::Libis::Workflow::Run.new
      end

      def logger
        Config.logger
      end

    end

  end
end
