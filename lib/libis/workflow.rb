# frozen_string_literal: true

require_relative 'exceptions'
require_relative 'workflow/version'

module Libis
  module Workflow

    autoload :Action, 'libis/workflow/action'
    autoload :Config, 'libis/workflow/config'
    autoload :Job, 'libis/workflow/job'
    autoload :MessageRegistry, 'libis/workflow/message_registry'
    autoload :Run, 'libis/workflow/run'
    autoload :StatusLog, 'libis/workflow/status_log'
    autoload :Task, 'libis/workflow/task'
    autoload :TaskGroup, 'libis/workflow/task_group'
    autoload :TaskRunner, 'libis/workflow/task_runner'
    autoload :VERSION, 'libis/workflow/version'
    autoload :WorkItem, 'libis/workflow/work_item'
    autoload :FileItem, 'libis/workflow/file_item'
    # autoload :Worker, 'libis/workflow/worker'

    module Base

      autoload :Logging, 'libis/workflow/base/logging'
      autoload :Status, 'libis/workflow/base/status'
      autoload :StatusEnum, 'libis/workflow/base/status_enum'
      autoload :TaskConfiguration, 'libis/workflow/base/task_configuration'
      autoload :TaskExecution, 'libis/workflow/base/task_execution'
      autoload :TaskHierarchy, 'libis/workflow/base/task_hierarchy'
      autoload :TaskLogging, 'libis/workflow/base/task_logging'

    end

    def self.configure
      yield Libis::Workflow::Config.instance
    end

  end
end
