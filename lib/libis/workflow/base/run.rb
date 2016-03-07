# encoding: utf-8

require 'fileutils'

require 'libis/workflow/base/work_item'

module Libis
  module Workflow
    module Base

      # Base module for all workflow runs. It is created by an associated workflow when the workflow is executed.
      #
      # This module lacks the implementation for the data attributes. It functions as an interface that describes the
      # common functionality regardless of the storage implementation. These attributes require some implementation:
      #
      # - start_date: [Time] the timestamp of the execution of the run
      # - job: [Object] a reference to the Job this Run belongs to
      # - id: [String] (Optional) a unique run number
      #
      # Note that ::Libis::Workflow::Base::WorkItem is a parent module and therefore requires implementation of the
      # attributes of that module too.
      #
      # A simple in-memory implementation can be found in ::Libis::Workflow::Run
      module Run
        include ::Libis::Workflow::Base::WorkItem

        attr_accessor :tasks, :action

        def work_dir
          # noinspection RubyResolve
          dir = File.join(Config.workdir, self.name)
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

          self.start_date = Time.now

          self.options = workflow.prepare_input(self.options)

          self.tasks = workflow.tasks
          configure_tasks self.options

          self.tasks.each do |task|
            task.run self
          end

        end

        protected

        def configure_tasks(opts)
          self.tasks.each { |task| task.apply_options opts }
        end

      end
    end
  end
end
