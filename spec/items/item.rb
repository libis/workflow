# encoding: utf-8

require 'libis/workflow/workitems'

class Item < ::LIBIS::Workflow::WorkItem

  attr_accessor :name

  def initialize
    @name = 'test_item'
    super
  end

  def to_string
    @name
  end

end