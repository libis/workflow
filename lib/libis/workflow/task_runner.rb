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

        recursive_run(item)
        self.workitem = item

      end

      private

      def recursive_run(item)

        item.properties['ingest_failed'] = item.check_status(:FAILED)

        item.summary = {}
        item.log_history.each do |log|
          level = log[:severity]
          item.summary[level.to_s] ||= 0
          item.summary[level.to_s] += 1
        end

        item.each do |i|
          recursive_run i
          i.summary.each do |level, count|
            item.summary[level] ||= 0
            item.summary[level] += (count || 0)
          end
        end

      rescue RuntimeError => ex

        self.workitem = item
        error 'Failed to analyze item: %s - %s', item, item.class, item.name
        error 'Exception: %s', item, ex.message

      ensure

        item.save!

      end

    end

  end
end
