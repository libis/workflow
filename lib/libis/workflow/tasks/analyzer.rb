# encoding: utf-8

require 'libis/workflow/task'

module LIBIS
  module Workflow
    module Tasks

      class Analyzer < Task

        def default_options
          { quiet: true, allways_run: true }
        end

        def start(item)

          item.properties[:ingest_failed] = item.failed?

          item.log_history.each do |log|
            level = log[:severity]
            item.summary[level] ||= 0
            item.summary[level] += 1
          end

          if item.respond_to? :each
            item.each do |i|
              start i
              i.summary.each do |level, count|
                item.summary[level] ||= 0
                item.summary[level] += (count || 0)
              end
            end
          end

          item.set_status :DONE
          item.save

        end

      end

    end
  end
end
