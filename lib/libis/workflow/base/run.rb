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
      #
      # Note that ::Libis::Workflow::Base::WorkItem is a parent module and therefore requires implementation of the
      # attributes of that module too.
      #
      # A simple in-memory implementation can be found in ::Libis::Workflow::Run
      module Run
        include ::Libis::Workflow::Base::WorkItem

        attr_accessor :tasks

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

        # Execute the workflow.
        def run

          self.start_date = Time.now

          self.options = workflow.prepare_input(self.options)

          self.tasks = workflow.tasks(self)
          configure_tasks self.options

          self.status = :STARTED

          self.tasks.each do |task|
            # note: do not return as we want to give any remaining task in the queue the oportunity to run
            next if self.failed? and not task.parameter(:always_run)
            task.run self
          end

          self.status = :DONE unless self.failed?

        end

        protected

        def configure_tasks(opts)
          self.tasks.each { |task| task.apply_options opts }
        end

      end
    end
  end
end
