# frozen_string_literal: true
require 'libis/tools/parameter'
require 'libis/tools/extend/hash'

module Libis
  module Workflow

    # This is the base module for Jobs.
    #
    # This module lacks the implementation for the data attributes. It functions as an interface that describes the
    # common functionality regardless of the storage implementation. These attributes require some implementation:
    #
    # - name: [String] the name of the Job. The name will be used to identify the job. Each time a job is executed,
    #     a Run will be created for the associated workflow. The Run will get a name that starts with the job name
    #     and ends with the date and time the Run was first started. As such this name attribute serves as an
    #     identifier and should be treated as such. If possible it should be unique.
    # - description: [String] optional information about the job.
    # - workflow: [Object] the workflow containing the tasks that need to run.
    #
    # A minimal in-memory implementation could be:
    #
    # class Job
    #   include ::Libis::Workflow::Job
    #
    #   attr_accessor :name, :description, :workflow
    #
    #   def initialize
    #     @name = ''
    #     @description = ''
    #     @input = Hash.new
    #     @workflow = ::Libis::Workflow::Workflow.new
    #     @run_object = ::Libis::Workflow::Run.new
    #   end
    #
    # end
    #
    module Job

      # @param [Hash] opts optional extra conguration values for this particular run
      def execute(opts = {})
        run = make_run(opts)
        raise RuntimeError.new "Could not create run" unless run

        run.execute(opts)
      end

      protected

      def make_run(opts)
        raise NotImplementedError, "Method not implemented: #{self.class}##{__method__.to_s}"
      end

      def run_name(timestamp = Time.now)
        "#{self.name}-#{timestamp.strftime('%Y%m%d%H%M%S')}"
      end

    end

  end
end
