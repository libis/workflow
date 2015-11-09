# encoding: utf-8
require 'sidekiq'

require 'libis/workflow/config'
require 'libis/workflow/workflow'

module Libis
  module Workflow

    class Worker
      include Sidekiq::Worker

      def perform(job_config, options = {})
        job = self.class.configure(job_config, options)
        options[:interactive] = false
        job.execute options
      end

      def self.configure(job_config, options = {})
        log_path = options.delete :log_path
        if log_path
          Config.logger = ::Logger.new(
              File.join(log_path, "#{job_config[:name]}.log"),
              (options.delete(:log_shift_age) || 'daily'),
              (options.delete(:log_shift_size) || 1024 ** 2)
          )
          Config.logger.formatter = ::Logger::Formatter.new
          Config.logger.level = ::Logger::DEBUG
        end
        get_job(job_config)
      end

      def get_job(job_config)
        job = ::Libis::Workflow::Job.new
        job.configure job_config
        job
      end

    end

  end
end
