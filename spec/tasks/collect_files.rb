# encoding: utf-8
require 'libis/exceptions'

require_relative '../items'

class CollectFiles < ::LIBIS::Workflow::Task

  parameter location: '.', description: 'Directory path to collect files from.'

  def process(item)
    if item.is_a? TestRun
      dir = TestDirItem.new
      dir.name = options[:location]
      item << dir
    elsif item.is_a? TestDirItem
      item.collect(TestFileItem, recursive: true)
    else
      # do nothin
    end
  end

end
