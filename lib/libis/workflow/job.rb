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
module Libis::Workflow::Job

  ### Methods that need implementation

  def name
    super
  end

  def name=(name)
    super
  end

  def make_run(options)
    super
  end

  ### Derived methods

  # @param [Hash] opts extra conguration values for this particular run
  def execute(opts = {})
    run = make_run(opts)
    raise 'Could not create run' unless run

    run.execute(opts)
  end

  def run_name(timestamp = Time.now)
    "#{name}-#{timestamp.strftime('%Y%m%d%H%M%S')}"
  end
end
