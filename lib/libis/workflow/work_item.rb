# frozen_string_literal: true

require 'backports/rails/hash'
require 'libis/tools/extend/hash'

require_relative 'config'
require_relative 'status'
require_relative 'logging'

# Base module for all work items.
#
# This module lacks the implementation for the data attributes. It functions as an interface that describes the
# common functionality regardless of the storage implementation. These attributes require some implementation:
#
# - name: [String] the name of the object
# - label: [String] the label of the object
# - parent: [Object|nil] a link to a parent work item. Work items can be organized in any hierarchy you think is
#     relevant for your workflow (e.g. directory[/directory...]/file/line or library/section/book/page). Of course
#     hierarchies are not mandatory.
# - items: [Enumerable] a list of child work items. see above.
# - options: [Hash] a set of options for the task chain on how to deal with this work item. This attribute can be
#     used to fine-tune the behaviour of tasks that support this.
# - properties: [Hash] a set of properties, typically collected during the workflow processing and used to store
#     final or intermediate resulst of tasks.
# - status_log: [Enumberable] a list of all status changes the work item went through.
#
# The module is created so that it is possible to implement an ActiveRecord/Datamapper/... implementation easily.
# A simple in-memory implementation would require:
#
# attr_accessor :parent
# attr_accessor :items
# attr_accessor :options, :properties
# attr_accessor :status_log
# attr_accessor :summary
#
# def initialize
#   self.parent = nil
#   self.items = []
#   self.options = {}
#   self.properties = {}
#   self.status_log = []
# end
#
# protected
#
# ## Method below should be adapted to match the implementation of the status array
#
# def add_status_log(info)
#   self.status_log << info
# end
#
# The implementation should also take care that the public methods #save and #save! are implemented.
# ActiveRecord and Mongoid are known to implement these, but others may not.
#
module Libis::Workflow::WorkItem
  include Libis::Workflow::Status
  include Libis::Workflow::Logging

  ### Methods that need implementation

  def parent
    super
  end

  def properties
    super
  end

  def options
    super
  end

  # @return [String] name of the object
  def name
    super
  rescue NoMethodError
    properties[:name] || inspect
  end

  def name=(name)
    super
  rescue NoMethodError
    properties[:name] = name
  end

  def label
    super
  rescue NoMethodError
    properties[:label] || name
  end

  def label=(value)
    super
  rescue NoMethodError
    properties[:label] = value
  end

  def items
    super
  end

  def add_item(item)
    super
  end

  alias << add_item

  # This method should return a list of items that is safe to iterate over while it is being altered.
  def item_list
    super
  end

  ### Derived methods. Should work as is when required methods are implemented properly

  def to_s
    name
  end

  def names
    (parent&.names || []).push(name).compact
  end

  def namepath
    names.join('/')
  end

  def labels
    (parent&.labels || []).push(label).compact
  end

  def labelpath
    labels.join('/')
  end

  # File name safe version of the to_s output.
  #
  # @return [String] file name safe string
  def safe_name
    to_s.gsub(/[^\w.-]/) { |s| format('%%%02x', s.ord) }
  end

  # Iterates over the work item clients and invokes code on each of them.
  def each(&block)
    items.each(&block)
  end

  def size
    items.size
  end

  alias count size

  def root_item
    parent&.root_item || self
  end
end
