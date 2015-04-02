# encoding: utf-8
require 'sidekiq'

require 'libis/workflow/config'
require 'libis/workflow/workflow'

module Libis
  module Workflow

    class Worker
      include Sidekiq::Worker

      def perform(workflow_config, options = {})
        workflow = self.class.configure(workflow_config, options)
        options[:interactive] = false
        workflow.run options
      end

      def self.configure(workflow_config, options = {})
        log_path = options.delete :log_path
        if log_path
          Config.logger = ::Logger.new(
              File.join(log_path, "#{workflow_config}.log"),
              (options.delete(:log_shift_age) || 'daily'),
              (options.delete(:log_shift_size) || 1024 ** 2)
          )
          Config.logger.formatter = ::Logger::Formatter.new
          Config.logger.level = ::Logger::DEBUG
        end
        get_workflow(workflow_config)
      end

      def get_workflow(workflow_config)
        workflow = ::Libis::Workflow::Workflow.new
        workflow.configure workflow_config
        workflow
      end

    end

  end
end
