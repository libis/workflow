# frozen_string_literal: true

require_relative 'test_work_item'

class TestDirItem < TestWorkItem

  include Libis::Workflow::FileItem

  def filename=(dir)
    raise "'#{dir}' is not a directory" unless File.directory? dir

    super
  end

end
