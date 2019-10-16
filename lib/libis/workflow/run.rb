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
module Libis
  module Workflow
    module Run

      include Base::Status

      ### Methods that need implementation in the including class
      # getter and setter accessors for:
      # - name
      # - config
      # getter accessors for:
      # - job
      # - options
      # - properties
      # instance methods:
      # - save!

      ### Derived methods

      def runner
        @runner ||= Libis::Workflow::TaskRunner.new self
      end

      def action
        properties[:action]
      end

      def action=(value)
        properties[:action] = value
      end

      def configure_tasks(tasks, opts = {})
        config[:tasks] = tasks
        runner.configure_tasks(tasks, opts)
      end

      # Execute the workflow.
      def execute(action = :start, opts = {})
        properties[:action] = action
        save!
        runner.execute(job, opts)
      end

      def status_log
        Config[:status_log].find_all(run: self)
      end

      def logger
        properties[:logger] || job&.logger || Libis::Workflow::Config.logger
      end

    end
  end
end
