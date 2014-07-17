# encoding: utf-8

require 'libis/exceptions'
require 'libis/workflow/config'

module LIBIS
  module Workflow

    autoload :WorkItem, 'libis/workflow/workitems/work_item'
    autoload :FileItem, 'libis/workflow/workitems/file_item'

    autoload :MessageRegistry, 'libis/workflow/message_registry'
    autoload :Task, 'libis/workflow/task'
    autoload :Worker, 'libis/workflow/worker'
    autoload :Workflow, 'libis/workflow/workflow'

    def self.configure
      yield Config.instance
    end

  end
end
