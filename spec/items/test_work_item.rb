# frozen_string_literal: true

class TestWorkItem

  include Libis::Workflow::WorkItem

  attr_accessor :parent
  attr_accessor :job
  attr_reader :items
  attr_reader :options, :properties

  def initialize
    @parent = nil
    @job = nil
    @items = []
    @options = {}
    @properties = {}
  end

  def name
    properties[:name]
  end

  def name=(value)
    properties[:name] = value
  end

  def label
    properties[:label]
  end

  def label=(value)
    properties[:label] = value
  end

  def save!; end

  def <<(item)
    @items << item
    item.parent = self
  end

  def item_list
    items.dup
  end

end
