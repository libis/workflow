require 'libis/tools/parameter'

module Libis
  module Workflow
    module Base

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
      # - run_obj: [String] the full class name of the Run implementation object that should be created when the
      #     Job is executed.
      # - input: [Hash] workflow input parameter values. Each input parameter of the workflow can be set by the entries
      #     in this Hash.
      #
      # A minimal in-memory implementation could be:
      #
      # class Job
      #   include ::Libis::Workflow::Base::Job
      #
      #   attr_accessor :name, :description, :workflow, :run_object, :input
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

        def run_name(timestamp = Time.now)
          "#{self.name}-#{timestamp.strftime('%Y%m%d%H%M%S')}"
        end

        def configure(cfg = {})
          self.name ||= ''
          self.description ||= ''
          self.input ||= {}
          self.name = cfg['name'] if cfg.has_key?('name')
          self.description = cfg['description'] if cfg.has_key?('description')
          self.workflow = cfg['workflow'] if cfg.has_key?('workflow')
          self.run_object = cfg['run_object'] if cfg.has_key?('run_object')
          self.input.merge!(cfg['input'] || {})
        end

        # noinspection RubyResolve
        # @param [Hash] opts optional extra conguration values for this particular run
        def execute(opts = {})
          run = self.create_run_object
          raise RuntimeError.new "Could not create instance of run object '#{self.run_object}'" unless run

          run.job = self
          (opts.delete('run_config') || {}).each { |key,value| run.send(key, value) }
          run.options = self.input.merge(opts)
          run.save!

          run.run

          run
        end

        protected

        # noinspection RubyResolve
        def create_run_object
          self.run_object.constantize.new
        end

      end
    end
  end
end
