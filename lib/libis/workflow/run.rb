require 'securerandom'

require 'libis/workflow/config'
require 'libis/workflow/workflow'

require 'libis/workflow/base/run'
require 'libis/workflow/work_item'

module Libis
  module Workflow

    class Run < ::Libis::Workflow::WorkItem
      include ::Libis::Workflow::Base::Run

      attr_accessor :start_date, :job, :id

      def initialize
        @start_date = Time.now
        @job = nil
        @id = SecureRandom.hex(10)
        super
      end

      def id
        nil
      end

      def reload
      end

      def logger
        self.properties[:logger] || (job.logger rescue nil)
      end

    end

  end
end