# encoding: utf-8
require 'libis/workflow/config'
require 'libis/exceptions'

module LIBIS
  module Workflow

    module Base
      autoload :Logger, 'libis/workflow/base/logger'
    end

    autoload :WorkItem, 'libis/workflow/workitems/work_item'
    autoload :FileItem, 'libis/workflow/workitems/file_item'
    autoload :DirItem, 'libis/workflow/workitems/dir_item'

    autoload :Run, 'libis/workflow/workitems/run'

    autoload :Definition, 'libis/workflow/definition'
    autoload :Task, 'libis/workflow/task'
    autoload :Worker, 'libis/workflow/worker'

    autoload :MessageRegistry, 'libis/workflow/message_registry'

    def self.configure
      yield Config.instance
    end

  end
end