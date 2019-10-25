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
        run.name
      end

      def action
        run.action
      end

      def action=(value)
        run.action = value
      end

      def execute(item, *_args)
        check_item_type item

        info 'Ingest run started.', item

        super
      end

    end
  end
end
