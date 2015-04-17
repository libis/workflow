# encoding: utf-8

require 'libis/tools/parameter'

module Libis
  module Workflow
    module Base
      module Workflow

        module ClassMethods
          def require_all
            Config.require_all(File.join(File.dirname(__FILE__), '..', 'tasks'))
            Config.require_all(Config.taskdir)
            Config.require_all(Config.itemdir)
          end
        end

        def self.included(base)
          base.extend ClassMethods
        end

        def name; raise RuntimeError.new "Method not implemented: #{caller[0]}"; end
        def name=(_) ; raise RuntimeError.new "Method not implemented: #{caller[0]}"; end

        def description; raise RuntimeError.new "Method not implemented: #{caller[0]}"; end
        def description=(_); raise RuntimeError.new "Method not implemented: #{caller[0]}"; end

        def config; raise RuntimeError.new "Method not implemented: #{caller[0]}"; end
        def config=(_); raise RuntimeError.new "Method not implemented: #{caller[0]}"; end

        def configure(cfg)
          self.config.merge! input: {}, tasks: []
          self.config.merge! cfg
          self.name = self.config.delete(:name) || self.class.name
          self.description = self.config.delete(:description) || ''

          self.class.require_all

          unless self.config[:tasks].last[:class] && self.config[:tasks].last[:class].split('::').last == 'Analyzer'
            self.config[:tasks] << {class: '::Libis::Workflow::Tasks::Analyzer'}
          end

          self.config
        end

        def input
          self.config[:input].inject({}) do |hash, input_def|
            parameter = ::Libis::Tools::Parameter.new input_def.first.to_sym
            input_def.last.each { |k, v| parameter[k.to_sym] = v}
            hash[input_def.first.to_sym] = parameter
            hash
          end
        end

        def run_name(timestamp = Time.now)
          "#{self.workflow.name}-#{timestamp.strftime('%Y%m%d%H%M%S')}"
        end

        def perform(opts = {})
          self.run opts
        end

        def create_run_object
          self.config[:run_object].constantize.new
        end

        # @param [Hash] opts
        def run(opts = {})

          run_object = self.create_run_object
          raise RuntimeError.new "Could not create instance of run object '#{self.config[:run_object]}'" unless run_object

          run_object.workflow = self
          run_object.options = opts
          run_object.save

          run_object.run opts

          run_object
        end

        # @param [Hash] opts
        def prepare_input(opts)
          options = opts.dup
          self.input.each do |key, parameter|
            key
            # provided in opts
            options[key] = parameter[:default] unless options.has_key? key
            options[key] = parameter.parse(options[key])
            propagate_to = []
            propagate_to = parameter[:propagate_to] if parameter[:propagate_to].is_a? Array
            propagate_to = [parameter[:propagate_to]] if parameter[:propagate_to].is_a? String
            propagate_to.each do |target|
              task_name, param_name = target.split('#')
              param_name ||= key
              options[task_name] ||= {}
              options[task_name][param_name.to_sym] = options[key]
            end
          end
          options
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
