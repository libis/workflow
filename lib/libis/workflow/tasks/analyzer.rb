# encoding: utf-8

require 'libis/workflow/task'

module Libis
  module Workflow
    module Tasks

      class Analyzer < Task

        parameter quiet: true, frozen: true
        parameter abort_on_error: false, frozen: true
        parameter always_run: true, frozen: true
        parameter subitems: false, frozen: true
        parameter recursive: false, frozen: true

        def run(item)

          item.properties[:ingest_failed] = item.failed?

          item.summary = {}
          item.log_history.each do |log|
            level = log[:severity]
            item.summary[level] ||= 0
            item.summary[level] += 1
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
