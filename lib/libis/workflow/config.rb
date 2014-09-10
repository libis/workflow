# encoding: utf-8

require 'singleton'
require 'logger'

module LIBIS
  module Workflow

    class Config
      include Singleton

      attr_accessor :logger, :workdir, :taskdir, :itemdir, :virusscanner

      def initialize
        @logger = ::Logger.new STDOUT
        @logger.formatter = proc do |severity, time, progname, msg|
          "%s, [%s#%d] %5s -- %s: %s\n" % [severity[0..0],
                                           (time.strftime('%Y-%m-%dT%H:%M:%S.') << '%06d ' % time.usec),
                                           $$, severity, progname, msg]
        end

        @workdir = './work'
        @taskdir = './tasks'
        @itemdir = './items'
        @virusscanner = {command: 'echo', options: {}}
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

      def self.workdir=(dir)
        instance.workdir = dir
      end

      def self.taskdir=(dir)
        instance.taskdir = dir
      end

      def self.itemdir=(dir)
        instance.itemdir = dir
      end

      def self.virusscanner
        instance.virusscanner
      end

      def self.virusscanner=(dir)
        instance.virusscanner = dir
      end

      def self.require_all(dir)
        instance
        return unless Dir.exist?(dir)
        Dir.glob(File.join(dir, '*.rb')).each do |filename|
          #noinspection RubyResolve
          require filename
        end
      end

    end

  end
end
