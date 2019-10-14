require 'libis/tools/parameter'
require 'libis/workflow/task_group'
require 'libis/tools/extend/hash'

# This is the base module for Workflows.
#
# This module lacks the implementation for the data attributes. It functions as an interface that describes the
# common functionality regardless of the storage implementation. These attributes require some implementation:
#
# - name: [String] the name of the Workflow. The name will be used to identify the workflow. Each time a workflow
#     is executed, a Run will be created. The Run will get a name that starts with the workflow name and ends with
#     the date and time the Run was started. As such this name attribute serves as an identifier and should be
#     treated as such. If possible is should be unique.
# - description: [String] more information about the workflow.
# - config: [Hash] detailed configuration for the workflow. The application assumes it behaves as a Hash and will
#     access it with [], merge! and delete methods. If your implementation decides to implement it with another
#     object, it should implement above methods. The config Hash requires the following keys:
#   - input: [Hash] all input parameter definitions where the key is the parameter name and the value is another
#       Hash with arguments for the parameter definition. It typically contains the following arguments:
#       - default: default value if no value specified when the workflow is executed
#       - propagate_to: the task name (or path) and parameter name that any set value for this parameter will be
#           propagated to. The syntax is <task name|task path>[#<parameter name>]. It the #<parameter name> part
#           is not present, the same name as the input parameter is used. If you want to push the value to
#           multiple task parameters, you can either supply an array of propagate paths or put them in a string
#           separated by a ','.
#   - tasks: [Array] task definitions that define the order in which the tasks should be executed for the workflow.
#       A task definition is a Hash with the following values:
#       - class: [String] the class name of the task including the module names
#       - name: [String] optional if class is present. A friendly name for the task that will be used in the logs.
#       - tasks: [Array] a list of subtask defintions for this task.
#
#       Additionally the task definition Hash may specify values for any other parameter that the task knows of.
#       All tasks have some fixed parameters. For more information about these see the documentation of
#       the task class.
#
#       A task definition does not require to have a 'class' entry. If not present the default
#       ::Libis::Workflow::TaskGroup class will be instatiated. It will do nothing itself, but will execute the
#       subtasks on the item(s). In such case a 'name' is mandatory.
#
# These values should be set by calling the #configure method which takes a Hash as argument with :name,
# :description, :input and :tasks keys.
#
# A minimal in-memory implementation could be:
#
# class Workflow
#   include ::Libis::Workflow::Base::Workflow
#
#   attr_accessor :name, :description, :config
#
#   def initialize
#     @name = ''
#     @description = ''
#     @config = Hash.new
#   end
#
# end
#
module Libis
  module Workflow
    module Base
      module Workflow

        module ClassMethods
          def require_all
            Libis::Workflow::Config.require_all(File.join(File.dirname(__FILE__), '..', 'tasks'))
            # noinspection RubyResolve
            Libis::Workflow::Config.require_all(Libis::Workflow::Config.taskdir)
            # noinspection RubyResolve
            Libis::Workflow::Config.require_all(Libis::Workflow::Config.itemdir)
          end
        end

        def self.included(base)
          base.extend ClassMethods
        end

        def configure(cfg)
          cfg.key_symbols_to_strings!(recursive: true)
          self.name = cfg.delete('name') || self.class.name
          self.description = cfg.delete('description') || ''
          self.config['input'] = {}
          self.config['tasks'] = []
          self.config.merge! cfg

          self.class.require_all

          self.config
        end

        def input
          self.config.key_strings_to_symbols(recursive: true)[:input].inject({}) do |hash, input_def|
            name = input_def.first
            default = input_def.last[:default]
            parameter = ::Libis::Tools::Parameter.new name, default
            input_def.last.each { |k, v| parameter[k] = v }
            hash[name] = parameter
            hash
          end
        rescue => _e
          {}
        end

        # @param [Hash] options
        def prepare_input(options)
          options = options.key_strings_to_symbols
          result = {}
          self.input.each do |key, parameter|
            value = nil
            if options.has_key?(key)
              value = parameter.parse(options[key])
            elsif !parameter[:default].nil?
              value = parameter[:default]
            else
              next
            end
            propagate_to = []
            propagate_to = parameter[:propagate_to] if parameter[:propagate_to].is_a? Array
            propagate_to = parameter[:propagate_to].split(/[\s,;]+/) if parameter[:propagate_to].is_a? String
            result[key] = value if propagate_to.empty?
            propagate_to.each do |target|
              task_name, param_name = target.split('#')
              param_name ||= key.to_s
              result[task_name] ||= {}
              result[task_name][param_name] = value
            end
          end
          result
        end

        def tasks(parent = nil)
          self.config['tasks'].map do |cfg|
            instantize_task(parent || nil, cfg)
          end
        end

        def instantize_task(parent, cfg)
          task_class = Libis::Workflow::TaskGroup
          task_class = cfg['class'].constantize if cfg['class']
          # noinspection RubyArgCount
          task_instance = task_class.new(parent, cfg)
          cfg['tasks'] && cfg['tasks'].map do |task_cfg|
            task_instance << instantize_task(task_instance, task_cfg)
          end
          task_instance
        end

      end
    end
  end
end
