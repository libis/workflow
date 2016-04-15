require_relative 'task_group'

module Libis
  module Workflow

    # noinspection RubyTooManyMethodsInspection
    class TaskRunner < Libis::Workflow::TaskGroup

      parameter abort_on_failure: true, frozen: true
      parameter recursive: false, frozen: true

      def names
        Array.new
      end

      def namepath
        'Run'
      end

      def run(item)

        check_item_type ::Libis::Workflow::Base::WorkItem, item
        self.workitem = item

        info 'Ingest run started.', item

        super

      end

    end

  end
end
