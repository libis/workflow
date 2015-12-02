# encoding: utf-8

require 'libis/tools/parameter'

module Libis
  module Workflow
    module Base

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
      #       - subitems: [Boolean] execute the task on the items in the current level or on the
      #           child items of the current level. This parameter can be used in combination with the subtasks to
      #           control what objects in the hierarchy the tasks are executed against.
      #       - recursive: [Boolean] execute the task for the current level items only or automatically recurse through
      #           the item's hierarchy and execute on all items below.
      #       - tasks: [Array] a list of subtask defintions for this task.
      #       Additionally the task definition Hash may specify values for any other parameter that the task knows of.
      #       All tasks have parameters 'quiet', 'always_run', 'abort_on_error'. For more information about these see
      #       the documentation of the task class.
      #       A task definition does not require to have a 'class' entry. If not present the default
      #       ::Libis::Workflow::Task class will be instatiated. It will do nothing itself, but will execute the
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
      module Workflow

        module ClassMethods
          def require_all
            Config.require_all(File.join(File.dirname(__FILE__), '..', 'tasks'))
            # noinspection RubyResolve
            Config.require_all(Config.taskdir)
            # noinspection RubyResolve
            Config.require_all(Config.itemdir)
          end
        end

        def self.included(base)
          base.extend ClassMethods
        end

        def configure(cfg)
          self.name = cfg.delete(:name) || self.class.name
          self.description = cfg.delete(:description) || ''
          self.config.merge! input: {}, tasks: []
          self.config.merge! cfg

          self.class.require_all

          unless self.config[:tasks].last[:class] && self.config[:tasks].last[:class].split('::').last == 'Analyzer'
            self.config[:tasks] << {class: '::Libis::Workflow::Tasks::Analyzer'}
          end

          self.config
        end

        def input
          self.config[:input].inject({}) do |hash, input_def|
            name = input_def.first.to_sym
            default = input_def.last[:default]
            parameter = ::Libis::Tools::Parameter.new name, default
            input_def.last.each { |k, v| parameter[k.to_sym] = v }
            hash[name] = parameter
            hash
          end
        rescue
          {}
        end

        # @param [Hash] options
        def prepare_input(options)
          result = {}
          self.input.each do |key, parameter|
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
              param_name ||= key
              result[task_name] ||= {}
              result[task_name][param_name.to_sym] = value
            end
          end
          result
        end

        def tasks(parent = nil)
          self.config[:tasks].map do |cfg|
            instantize_task(parent || self, cfg)
          end
        end

        def instantize_task(parent, cfg)
          task_class = Task
          task_class = cfg[:class].constantize if cfg[:class]
          # noinspection RubyArgCount
          task_instance = task_class.new(parent, cfg)
          cfg[:tasks].map do |task_cfg|
            task_instance << instantize_task(task_instance, task_cfg)
          end rescue nil
          task_instance
        end

      end
    end
  end
end
