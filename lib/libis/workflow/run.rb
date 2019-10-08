# frozen_string_literal: true
require 'fileutils'

require 'libis/workflow/task_runner'

module Libis
  module Workflow

    # Base module for all workflow runs. It is created by job when the job is executed.
    #
    # This module lacks the implementation for the data attributes. It functions as an interface that describes the
    # common functionality regardless of the storage implementation. These attributes require some implementation:
    #
    # - start_date: [Time] the timestamp of the execution of the run
    # - job: [Object] a reference to the Job this Run belongs to
    # - id: [String] (Optional) a unique run number
    #
    # A simple in-memory implementation can be found in ::Libis::Workflow::Run
    module Run

      attr_accessor :tasks, :action

      def work_dir
        # noinspection RubyResolve
        dir = File.join(Libis::Workflow::Config.workdir, self.name)
        FileUtils.mkpath dir unless Dir.exist?(dir)
        dir
      end

      def name
        self.job.run_name(self.start_date)
      end

      def names
        Array.new
      end

      def namepath
        self.name
      end

      def workflow
        self.job.workflow
      end

      def logger
        self.properties['logger'] || self.job.logger rescue ::Libis::Workflow::Config.logger
      end

      # Execute the workflow.
      #
      # The action parameter defines how the execution of the tasks will behave:
      #  - With the default :run action each task will be executed regardsless how the task performed on the item
      #    previously.
      #  - When using the :retry action a task will not perform on an item if it was successful the last time. This
      #    allows you to retry a run when an temporary error (e.g. asynchronous wait or halt) occured.
      #
      # @param [Symbol] action the type of action to take during this run. :run or :retry
      def run(action = :run)
        self.action = action

        unless action == :retry
          self.start_date = Time.now
          self.options = workflow.prepare_input(self.options)
        end


        self.tasks = workflow.tasks
        configure_tasks self.options

        self.save!

        runner = Libis::Workflow::TaskRunner.new nil

        self.tasks.each do |task|
          runner << task
        end

        runner.run self

      end

      protected

      def configure_tasks(opts)
        self.tasks.each { |task| task.apply_options opts }
      end

    end

  end
end
