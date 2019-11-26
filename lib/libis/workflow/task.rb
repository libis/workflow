# frozen_string_literal: true

require 'backports/rails/hash'
require 'backports/rails/string'

require 'libis/tools/parameter'
require 'libis/tools/extend/hash'
require 'libis/tools/logger'

require 'libis/workflow'
require_relative 'base/task_status'

module Libis
  module Workflow
    class Task

      include ::Libis::Tools::Logger
      include ::Libis::Tools::ParameterContainer

      include Base::TaskStatus
      include Base::TaskConfiguration
      include Base::TaskExecution
      include Base::TaskHierarchy
      include Base::TaskLogging

      attr_accessor :properties

      def self.abort_on_failure(v = nil)
        @abort_on_failure = v unless v.nil?
        return @abort_on_failure unless @abort_on_failure.nil?
        superclass.abort_on_failure rescue false
      end

      def abort_on_failure
        self.class.abort_on_failure
      end

      def self.retry_count(v = nil)
        @retry_count = v unless v.nil?
        return @retry_count unless @retry_count.nil?
        superclass.retry_count rescue 0
      end

      def retry_count
        self.class.retry_count
      end

      def self.retry_interval(v = nil)
        @retry_interval = v unless v.nil?
        return @retry_interval unless @retry_interval.nil?
        superclass.retry_interval rescue 10
      end

      def retry_interval
        self.class.retry_interval
      end

      def self.run_always(v = nil)
        @run_always = v unless v.nil?
        return @run_always unless @run_always.nil?
        superclass.run_always rescue false
      end

      def run_always
        self.class.run_always
      end

      def self.recursive(v = nil)
        @recursive = v unless v.nil?
        return @recursive unless @recursive.nil?
        superclass.recursive rescue true
      end

      def recursive
        self.class.recursive
      end

      def self.task_classes
        #noinspection RubyArgCount
        ObjectSpace.each_object(::Class).select { |klass| klass < self && !klass.is_a?(TaskGroup) }
      end

      def initialize(cfg = {})
        configure cfg[:parameters] || {}
        @properties = cfg.dup
      end

      def allowed_item_types
        [Job, WorkItem]
      end

      def check_item_type(item, *args, raise_on_error: true)
        klasses = args.empty? ? allowed_item_types : args
        unless klasses.any? { |klass| item.is_a? klass }
          return false unless raise_on_error
          raise WorkflowError, "Item is of wrong type : #{item.class.name} - expected one of #{klasses.map(&:name)}"
        end

        true
      end

      def name
        self.class.name.split('::').last
      end

      def names
        parent&.names&.push(name) || [name]
      end

      def namepath
        names.join('/')
      end

      def to_s
        namepath
      end

      def <<(_task)
        raise Libis::WorkflowError, "Processing task '#{namepath}' is not allowed to have subtasks."
      end

      # @return [Libis::Workflow::Run]
      def run
        parent&.run || nil
      end

      def work_dir
        run&.job&.work_dir
      end

      def item_type?(klass, item)
        item.is_a? klass.to_s.constantize
      end

      def status_log
        Config[:status_log].find_all(task: self)
      end

      def last_status
        Config[:status_log].find_all(run: self) &.status_sym || StatusEnum.keys.first
      end

    end
  end
end
