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
      attr_reader :tasks

      # @param [Hash] config Workflow configuration
      def initialize(config)

        @tasks = []
        set_config(config)
      end

      def set_config(config)
        @config = {input: [], tasks: [], run_object: '::LIBIS::Workflow::WorkItem'}.merge config
        self.config[:name] ||= self.class.name

        Config.require_all(File.join(File.dirname(__FILE__), 'tasks'))
        Config.require_all(Config.taskdir)
        Config.require_all(Config.itemdir)

        unless self.config[:tasks].last[:class] && self.config[:tasks].last[:class].split('::').last == 'Analyzer'
          self.config[:tasks] << { class: '::LIBIS::Workflow::Tasks::Analyzer' }
        end

        self.tasks.clear
        self.config[:tasks].each do |m|
          task_class = Task
          task_class    = m[:class].constantize if m[:class]
          task_instance = task_class.new nil, m.symbolize_keys!
          self.tasks << {
              class:    task_class,
              instance: task_instance
          }
        end
      end

      def name
        self.config[:name]
      end

      def input
        self.config[:input]
      end

      # @param [Hash] opts
      def run(opts = {})

        run_object = self.config[:run_object].constantize.new
        raise RuntimeError.new "Could not create instance of run object '#{self.config[:run_object]}'" unless run_object

        run_object.parent = self
        run_object.options = opts
        run_object.save

        process_options opts

        check_item_type WorkItem

        @tasks.each do |m|
          next if workitem.failed? and not m[:instance].options[:allways_run]
          m[:instance].run(workitem)
        end

        workitem.status = :DONE unless workitem.failed?

      end

      def inputs_required
        (@inputs || {}).reject { |_, input| input.has_key?(:default) }
      end

      private

      # @param [Hash] opts
      def process_options(opts)
        options = opts.dup
        @action = options.delete(:action) || 'start'
        options = prepare_input options, @inputs
        options.each { |k,v| workitem.options[k.to_sym] = v }
      end

      # @param [Hash] opts
      # @param [Array] inputs
      def prepare_input(opts, inputs)
        options = opts.symbolize_keys
        interactive = options.delete :interactive
        (inputs || {}).each do |key, input|
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
              options[key] = s_to_time options[key]
            when 'Boolean'
              options[key] = %w'true yes t y 1'.include? options[key].downcase if options[key].is_a?(String)
            else
              options[key].gsub!('%s',Time.now.strftime('%Y%m%d%H%M%S')) if options[key].is_a? String
          end
        end
        options
      end

      # @param [String] str
      # @return [Time]
      def s_to_time(str)
        d = str.split %r'[/ :.-]'
        Time.new *d
      end

    end

  end
end

