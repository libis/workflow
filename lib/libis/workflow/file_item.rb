require 'digest'

require 'libis/workflow/base/file_item'
require 'libis/workflow/work_item'

module Libis
  module Workflow

    # noinspection RubyResolve
    class FileItem < ::Libis::Workflow::WorkItem
      include ::Libis::Workflow::Base::FileItem

    end
  end
end
