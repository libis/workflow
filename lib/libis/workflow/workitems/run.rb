# encoding: utf-8

require 'libis/workflow/workitems/work_item'
require 'libis/workflow/definition'

module LIBIS
  module Workflow

    module Run
      include WorkItem

      def workflow
        raise RuntimeError.new 'Missing workflow definition' unless self.parent and self.parent.is_a? Definition
        parent
      end

      def tasks
        self.workflow.tasks
      end

      # @param [Hash] opts
      def run(opts = {})

        process_options opts

        tasks.each do |m|
          next if workitem.failed? and not m[:instance].options[:allways_run]
          m[:instance].run(workitem)
        end

        workitem.status = :DONE unless workitem.failed?

      end


    end

  end
end