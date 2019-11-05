# frozen_string_literal: true

require 'libis/tools/parameter'
require 'libis/tools/extend/hash'

# This is the base module for Jobs.
#
# This module lacks the implementation for the data attributes. It functions as an interface that describes the
# common functionality regardless of the storage implementation. These attributes require some implementation:
#
# - name: [String] the name of the Job. The name will be used to identify the job. Each time a job is executed,
#     a Run will be created for the associated workflow. The Run will get a name that starts with the job name
#     and ends with the date and time the Run was first started. As such this name attribute serves as an
#     identifier and should be treated as such. If possible it should be unique.
# - workflow: [Object] the workflow that has access to the tasks that need to run.
#
# A minimal in-memory implementation could be:
#
# class Job
#   include ::Libis::Workflow::Job
#
#   attr_accessor :name, :workflow
#
#   def initialize
#     @name = ''
#     @workflow = ::Libis::Workflow::Workflow.new
#   end
#
# end
#
module Libis
  module Workflow
    module Job

      ### Methods that need implementation in the including class
      # getter and setter accessors for:
      # - name
      # getter accessors for:
      # - workflow
      # - runs
      # - items
      # - work_dir
      # instance methods:
      # - <<
      # - item_list
      # - make_run
      # - last_run

      ### Derived methods

      # @param [Array] args extra conguration values for this particular run
      def execute(*args)
        run = prepare(*args)
        perform(run, *args)
        finish(run, *args)
        run
      end

      def prepare(*args)
        run = make_run(*args)
        raise 'Could not create run' unless run

        run.configure_tasks(tasks, *args)
        run
      end

      def perform(run, *args)
        opts = args.last.is_a?(Hash) ? args.last : {}
        run.execute (opts[:action] || :start), *args
      end

      def finish(_run, *_args); end

      def tasks
        workflow.tasks
      end

      def run_name(timestamp = Time.now)
        "#{name}-#{timestamp.strftime('%Y%m%d%H%M%S')}"
      end

      def names
        []
      end

      def namepath
        name
      end

      def labels
        []
      end

      def to_dir
        work_dir
      end

      def job
        self
      end

      def status_log
        Config[:status_log].find_all(item: self)
      end

      def last_status_log
        Config[:status_log].find_all_last(self)
      end

      def last_status(task)
        task = task.namepath if task.is_a?(Libis::Workflow::Task)
        Config[:status_log].find_last(item: self, task: task)&.status_sym || Base::StatusEnum.keys.first
      end

      def logger
        Config.logger
      end

    end
  end
end
