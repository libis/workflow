# encoding: utf-8
require 'libis/exceptions'

module LIBIS
  module Workflow

    autoload :MessageRegistry, 'libis/workflow/message_registry'
    autoload :Config, 'libis/workflow/config'

    autoload :WorkItem, 'libis/workflow/workitems/work_item'
    autoload :FileItem, 'libis/workflow/workitems/file_item'
    autoload :DirItem, 'libis/workflow/workitems/dir_item'

    autoload :Workflow, 'libis/workflow/workflow'
    autoload :Run, 'libis/workflow/run'
    autoload :Task, 'libis/workflow/task'

    autoload :Parameter, 'libis/workflow/parameter'

    autoload :Worker, 'libis/workflow/worker'

    def self.configure
      yield Config.instance
    end

  end
end

