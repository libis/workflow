# frozen_string_literal: true

require_relative 'task_group'

module Libis
  module Workflow
    # noinspection RubyTooManyMethodsInspection
    class TaskRunner < TaskGroup

      parameter abort_on_failure: true, frozen: true
      parameter recursive: false, frozen: true

      def initialize(run, cfg = {})
        @run = run
        super cfg
      end

      def run
        @run
      end

      def names
        []
      end

      def namepath
        ''
      end

      def execute(item)
        check_item_type [WorkItem, Job], item

        info 'Ingest run started.', item

        super
      end

    end
  end
end
