require 'libis/workflow/task'

module Libis
  module Workflow
    module Tasks

      class Analyzer < Task

        parameter quiet: true, frozen: true
        parameter recursive: false, frozen: true

        # @param [Libis::Workflow::Base::WorkItem] item
        def run(item)

          item.properties[:ingest_failed] = item.check_status(:FAILED)

          item.summary = {}
          item.log_history.each do |log|
            level = log[:severity]
            item.summary[level.to_s] ||= 0
            item.summary[level.to_s] += 1
          end

          item.each do |i|
            run i
            i.summary.each do |level, count|
              item.summary[level] ||= 0
              item.summary[level] += (count || 0)
            end
          end

        rescue RuntimeError => ex

          puts 'Failed to analyze item: %s - %s' % [item.class, item.name]
          puts 'Exception: %s' % ex.message

        ensure

          item.save

        end

      end

    end
  end
end
