# encoding: utf-8

require 'libis/workflow/base/workflow'

module Libis
  module Workflow

    class Workflow
      include ::Libis::Workflow::Base::Workflow

      attr_accessor :name, :description, :config

      def initialize
        @name = ''
        @description = ''
        @config = Hash.new
      end

    end

  end
end
