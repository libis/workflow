# encoding: utf-8

require 'backports/rails/string'
require 'backports/rails/hash'

require 'libis/workflow/config'
require 'libis/workflow/task'
require 'libis/workflow/tasks/analyzer'

module LIBIS
  module Workflow

    class Definition

      attr_reader :config

      # @param [Hash] config Workflow configuration
      def initialize(config)
        self.config = config
      end

      def config=(cfg)
        @config = {input: [], tasks: [], run_object: '::LIBIS::Workflow::WorkItem'}.merge cfg
        self.config[:name] ||= self.class.name

        Config.require_all(File.join(File.dirname(__FILE__), 'tasks'))
        Config.require_all(Config.taskdir)
        Config.require_all(Config.itemdir)

        unless self.config[:tasks].last[:class] && self.config[:tasks].last[:class].split('::').last == 'Analyzer'
          self.config[:tasks] << {class: '::LIBIS::Workflow::Tasks::Analyzer'}
        end

        self.config
      end

      def name
        self.config[:name]
      end

      def input
        self.config[:input]
      end

      def inputs_required
        (self.input || {}).reject { |_, input| input.has_key?(:default) }
      end

      # @param [Hash] opts
      def run(opts = {})

        run_object = self.config[:run_object].constantize.new
        raise RuntimeError.new "Could not create instance of run object '#{self.config[:run_object]}'" unless run_object

        run_object.parent = self
        run_object.options = opts
        run_object.save

        run_object.run

        run_object
      end

      # @param [Hash] opts
      def prepare_input(opts)
        options = opts.symbolize_keys
        interactive = options.delete :interactive
        (self.input || {}).each do |key, input|
          # provided in opts
          unless options.has_key? key
            if input.has_key? :default
              # not provided in opts, but default exists
              options[key] = input[:default]
            else
              raise StandardError.new "input option '#{input[:name]}' has no value." unless interactive
              # ask user
              puts input[:description] if input[:description]
              print "#{input[:name] || key.to_s} : "
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
        end
        options
      end

      # @param [String] str
      # @return [Time]
      def self.s_to_time(str)
        d = str.split %r'[/ :.-]'
        Time.new *d
      end

      def tasks
        self.config[:tasks].map do |cfg|
          instantize_task(self, cfg)
        end
      end

      def instantize_task(parent, cfg)
        cfg.symbolize_keys!
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

