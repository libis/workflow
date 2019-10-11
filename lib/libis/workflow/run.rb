# frozen_string_literal: true

require 'fileutils'

# Base module for all workflow runs. It is created by job when the job is executed.
#
# This module lacks the implementation for the data attributes. It functions as an interface that describes the
# common functionality regardless of the storage implementation. These attributes require some implementation:
#
# - name: [String] the name of the Run
# - start_date: [Time] the timestamp of the execution of the run
# - job: [Object] a reference to the Job this Run belongs to
#
module Libis::Workflow
  module Run
    include Base::Status

    attr_accessor :runner

    ### Methods that need implementation in the including class
    #
    # save!
    # name
    # name=(name)
    # job
    # last_run
    # status(task)

    ### Derived methods

    def runner
      @runner ||= Libis::Workflow::TaskRunner.new self
    end

    def configure_tasks(tasks)
      runner.configure_tasks(tasks)
    end

    # Execute the workflow.
    #
    # @param [Hash] options extra run-time options
    def execute(options = {})

      runner.configure()
      # configure_tasks(options)

      send(:save!)

      runner.execute(send(:job))
    end

    def logger
      send(:properties)['logger'] || send(:job).logger
    rescue StandardError
      ::Libis::Workflow::Config.logger
    end

  end
end
