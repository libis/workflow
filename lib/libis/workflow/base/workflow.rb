# encoding: utf-8

module LIBIS
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
          self.config.merge! input: [], tasks: []
          self.config.merge! cfg
          self.name = self.config.delete(:name) || self.class.name
          self.description = self.config.delete(:description) || ''

          self.class.require_all

          unless self.config[:tasks].last[:class] && self.config[:tasks].last[:class].split('::').last == 'Analyzer'
            self.config[:tasks] << {class: '::LIBIS::Workflow::Tasks::Analyzer'}
          end

          self.config
        end

        def input
          self.config[:input]
        end

        def inputs_required
          (self.input || {}).reject { |_, input| input.has_key?(:default) }
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
          interactive = options.delete :interactive
          (self.input || {}).each do |key, input|
            # provided in opts
            unless options.has_key? key
              if input.has_key? :default
                # not provided in opts, but default exists
                options[key] = input[:default]
              else
                raise StandardError.new "input option '#{key}' has no value." unless interactive
                # ask user
                puts input[:description] if input[:description]
                print "#{key} : "
                value = STDIN.gets.strip
                options[key] = value
              end
            end
            case input[:type]
              when 'Time'
                options[key] = self.class.s_to_time options[key]
              when 'Boolean'
                options[key] = %w'true yes t y 1'.include? options[key].downcase if options[key].is_a?(String)
              else
                options[key].gsub!('%s', Time.now.strftime('%Y%m%d%H%M%S')) if options[key].is_a? String
            end
            (input[:propagate_to] || []).each do |target|
              o = options
              path = target[:class].split('/')
              path[0...-1].each { |p| o = (o[p] ||= {})}
              target_key = target[:key].to_sym rescue key
              (o[path.last] ||= {})[target_key] ||= options[key]
            end
          end
          options
        end

        # @param [String] str
        # @return [Time]
        def self.s_to_time(str)
          d = str.split %r'[/ :.-]'
          Time.new *d
        end

        def tasks(parent = nil)
          self.config[:tasks].map do |cfg|
            instantize_task(parent || self, cfg)
          end
        end

        def instantize_task(parent, cfg)
          task_class = Task
          task_class = cfg[:class].constantize if cfg[:class]
          task_instance = task_class.new parent, cfg
          cfg[:tasks].map do |task_cfg|
            task_instance << instantize_task(task_instance, task_cfg)
          end rescue nil
          task_instance
        end

      end
    end
  end
end
