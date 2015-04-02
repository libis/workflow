# encoding: utf-8

require 'singleton'
require 'logger'

module Libis
  module Workflow

    class Config
      include Singleton

      attr_accessor :logger, :workdir, :taskdir, :itemdir

      private

      def initialize
        Config.require_all(File.join(File.dirname(__FILE__), 'tasks'))
        @logger = ::Logger.new STDOUT
        set_formatter
        @workdir = './work'
        self.taskdir = './tasks'
        self.itemdir = './items'
      end

      public

      def set_formatter(formatter = nil)
        @logger.formatter = formatter || proc do |severity, time, progname, msg|
          "%s, [%s#%d] %5s -- %s: %s\n" % [severity[0..0],
                                           (time.strftime('%Y-%m-%dT%H:%M:%S.') << '%06d ' % time.usec),
                                           $$, severity, progname, msg]
        end
      end

      def self.logger
        instance.logger
      end

      def self.workdir
        instance.workdir
      end

      def self.taskdir
        instance.taskdir
      end

      def self.itemdir
        instance.itemdir
      end

      def self.logger=(log)
        instance.logger = log
      end

      def self.set_formatter(formatter = nil)
        instance.set_formatter(formatter)
      end

      def self.workdir=(dir)
        instance.workdir = dir
      end

      def taskdir=(dir)
        @taskdir = dir
        Config.require_all dir
      end

      def self.taskdir=(dir)
        instance.taskdir = dir
      end

      def itemdir=(dir)
        @itemdir = dir
        Config.require_all dir
      end

      def self.itemdir=(dir)
        instance.itemdir = dir
      end

      def self.require_all(dir)
        return unless Dir.exist?(dir)
        Dir.glob(File.join(dir, '*.rb')).each do |filename|
          #noinspection RubyResolve
          require filename
        end
      end

    end

  end
end
