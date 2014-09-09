# encoding: utf-8
require 'libis/workflow/workitems'

class TestFileItem < ::LIBIS::Workflow::WorkItem
  include ::LIBIS::Workflow::FileItem

  def initialize(file)
    super()
    raise RuntimeError, "'#{file}' is not a file" unless File.file? file
    set_file file
  end

  def name
    @name ||= filename
  end

  def name=(n)
    @name = n
  end

  def to_s
    name
  end

  def filesize
    properties[:size]
  end

  def fixity_check(checksum)
    properties[:checksum] == checksum
  end

end