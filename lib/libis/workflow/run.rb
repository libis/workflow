# encoding: utf-8

require 'libis/workflow/config'
require 'libis/workflow/workflow'

require 'libis/workflow/base/run'

module LIBIS
  module Workflow

    class Run
      include ::LIBIS::Workflow::Base::Run

      attr_accessor :start_date, :tasks, :workflow

      def initialize
        @start_date = Time.now
        @tasks = nil
        @workflow = nil
        # noinspection RubySuperCallWithoutSuperclassInspection
        super
      end

    end

  end
end