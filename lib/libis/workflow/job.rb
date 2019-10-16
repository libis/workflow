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
      # instance methods:
      # - <<
      # - item_list
      # - make_run
      # - last_run

      ### Derived methods

      # @param [Hash] opts extra conguration values for this particular run
      def execute(opts = {})
        run = prepare(opts)
        perform(run, opts)
        finish(run, opts)
        run
      end

      def prepare(opts = {})
        run = make_run(opts)
        raise 'Could not create run' unless run
        run.configure_tasks(tasks, opts)
        run
      end

      def perform(run, opts = {})
        run.execute (opts[:action] || :start), opts
      end

      def finish(_run, _opts = {}); end

      def tasks
        workflow.tasks
      end

      def run_name(timestamp = Time.now)
        "#{name}-#{timestamp.strftime('%Y%m%d%H%M%S')}"
      end

      def namepath
        name
      end

      def status_log
        Config[:status_log].find_all(run: runs.last, item: self)
      end

      def logger
        Config.logger
      end

    end
  end
end
