# encoding: utf-8
require 'libis/exceptions'

require_relative '../items'

class CollectFiles < ::LIBIS::Workflow::Task
  def process
    if item_type? TestRun
      workitem << TestDirItem.new(workitem.options[:dirname])
    elsif item_type? TestDirItem
      collect_files workitem
    else
      # do nothin
    end
  end

  def collect_files(dir_item)
    base_dir = dir_item.long_name
    dir_item.dir_list.sort.each do |dirname|
      workitem << TestDirItem.new(File.join(base_dir, dirname))
    end
    dir_item.file_list.sort.each do |filename|
      workitem << TestFileItem.new(File.join(base_dir, filename))
    end
  end

end
