# encoding: utf-8

require 'backports/rails/string'
require 'backports/rails/hash'

require 'libis/workflow/config'
require 'libis/workflow/task'
require 'libis/workflow/tasks/analyzer'

require 'libis/workflow/base/workflow'

module LIBIS
  module Workflow

    class Workflow
      include ::LIBIS::Workflow::Base::Workflow

      attr_accessor :name, :description, :config

      def initialize
        @name = ''
        @descripition = ''
        @config = Hash.new
      end

    end

  end
end
