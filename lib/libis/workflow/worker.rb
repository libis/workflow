# encoding: utf-8

require 'libis/workflow/config'
require 'libis/workflow/workflow'

module LIBIS
  module Workflow

    class Worker

      attr_accessor :workflow_name, :options
      attr_reader :workflow

      def initialize(workflow_name, options = {})

        @workflow_name = workflow_name
        log_path = options.delete :log_path
        if log_path
          Config.logger = ::Logger.new(
              File.join(log_path, "#{workflow_name}.log"),
              (options.delete(:log_shift_age) || 'daily'),
              (options.delete(:log_shift_size) || 1024 ** 2)
          )
          Config.logger.formatter = ::Logger::Formatter.new
          Config.logger.level = ::Logger::DEBUG
        end

        @workflow = Workflow.new workflow_name

      end

      def start(options = {})
        options[:interactive] = true
        @workflow.run options
      end

      def run(options = {})
        options[:interactive] = false
        @workflow.run options
      end

    end

  end
end
