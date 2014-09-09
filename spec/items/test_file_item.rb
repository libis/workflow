# encoding: utf-8
require 'libis/workflow/workitems'

class TestFileItem
  include ::LIBIS::Workflow::FileItem

  def initialize(file)
    super()
    raise RuntimeError, "'#{file}' is not a file" unless File.file? file
    self.name = file
  end

  def filesize
    properties[:size]
  end

  def fixity_check(checksum)
    properties[:checksum] == checksum
  end

end