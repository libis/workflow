# encoding: utf-8

require 'libis/tools/config'

module Libis
  module Workflow

    class Config < ::Libis::Tools::Config

      private

      def initialize
        super
        Config.require_all(File.join(File.dirname(__FILE__), 'tasks'))
        self[:workdir] = './work'
        self[:taskdir] = './tasks'
        self[:itemdir] = './items'
      end

      public

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
