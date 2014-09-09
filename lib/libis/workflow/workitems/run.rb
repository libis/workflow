# encoding: utf-8

require 'libis/workflow/workitems/work_item'
require 'libis/workflow/definition'

module LIBIS
  module Workflow

    module Run
      include WorkItem

      def workflow
        raise RuntimeError.new 'Missing workflow definition' unless self.parent and self.parent.is_a? Definition
        self.parent
      end

      def tasks
        @task_instances ||= self.workflow.tasks
      end

      def name
        self.class.name
      end

      def run(opts = {})

        self.options = workflow.prepare_input(self.options.merge(opts))

        self.tasks.each do |task|
          next if self.failed? and not task.options[:allways_run]
          task.run self
        end

        self.status = :DONE unless self.failed?

      end

    end

  end
end