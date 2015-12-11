# encoding: utf-8
require 'libis/exceptions'

module Libis
  module Workflow

    autoload :MessageRegistry, 'libis/workflow/message_registry'
    autoload :Config, 'libis/workflow/config'

    module Base
      autoload :WorkItem, 'libis/workflow/base/work_item'
      autoload :FileItem, 'libis/workflow/base/file_item'
      autoload :DirItem, 'libis/workflow/base/dir_item'
      autoload :Logger, 'libis/workflow/base/logger'
      autoload :Logging, 'libis/workflow/base/logging'
      autoload :Job, 'libis/workflow/base/job'
      autoload :Run, 'libis/workflow/base/run'
      autoload :Workflow, 'libis/workflow/base/workflow'
    end

    autoload :Status, 'libis/workflow/status'

    autoload :WorkItem, 'libis/workflow/work_item'
    autoload :FileItem, 'libis/workflow/file_item'
    autoload :DirItem, 'libis/workflow/dir_item'

    autoload :Workflow, 'libis/workflow/workflow'
    autoload :Job, 'libis/workflow/job'
    autoload :Run, 'libis/workflow/run'
    autoload :Task, 'libis/workflow/task'

    autoload :Worker, 'libis/workflow/worker'

    def self.configure
      yield Config.instance
    end

  end
end
