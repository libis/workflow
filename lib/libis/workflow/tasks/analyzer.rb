# encoding: utf-8

require 'libis/workflow/task'

module LIBIS
  module Workflow
    module Tasks

      class Analyzer < Task

        def default_options
          { quiet: true, allways_run: true }
        end

        def run(item)

          item.properties[:ingest_failed] = item.failed?

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

          item.save

        end

      end

    end
  end
end
