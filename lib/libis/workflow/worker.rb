# frozen_string_literal: true

require 'libis/tools/extend/hash'
require 'libis/workflow/config'

module Libis
  module Workflow
    class Worker

      def perform(job_config, options = {})
        job = configure(job_config, options)
        options[:interactive] = false
        job.execute options
      end

      def configure(job_config, options = {})
        log_path = options.delete :log_path
        if log_path
          Libis::Workflow::Config.logger = ::Logger.new(
            File.join(log_path, "#{job_config[:name]}.log"),
            (options.delete(:log_shift_age) || 'daily'),
            (options.delete(:log_shift_size) || 1024**2)
          )
          Libis::Workflow::Config.logger.formatter = ::Logger::Formatter.new
          Libis::Workflow::Config.logger.level = (options.delete(:log_level) || ::Logger::DEBUG)
        end
        get_job(job_config)
      end

      def get_job(job_config)
        job = ::Libis::Workflow::Job.new
        job.configure job_config.key_symbols_to_strings(recursive: true)
        job
      end

    end
  end
end
