# encoding: utf-8

require 'libis/workflow/task'
require 'libis/workflow/workitems'
require 'libis/workflow/config'
require 'libis/workflow/exception'

module LIBIS
  module Workflow
    module Tasks

      class VirusChecker < Task

        def process_item(item)

          return unless item_type? FileItem, item
          return unless item_type? WorkItem, item
          return unless item.options[:filename]

          if item.options[:virus_check]
            debug 'Skipping file. Already checked.'
            return
          end

          debug 'Scanning file for virusses'

          cmd_options = Config.virusscanner[:options]
          status, _, err = capture_cmd Config.virusscanner[:command], *cmd_options, item.filename
          raise Exception, "Error during viruscheck: #{err}" unless status

          item.options[:virus_check] = true
          info 'File is clean'

        end

      end

    end
  end
end
