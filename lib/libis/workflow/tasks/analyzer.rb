require 'libis/workflow/task'

module Libis
  module Workflow
    module Tasks

      class Analyzer < Task

        parameter quiet: true, frozen: true
        parameter recursive: false, frozen: true

        # @param [Libis::Workflow::Base::WorkItem] item
        def run(item)

          recursive_run(item)
          self.workitem = item
          info 'Ingest finished', item

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
end
