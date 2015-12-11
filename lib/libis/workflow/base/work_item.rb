# encoding: utf-8

require 'backports/rails/hash'
require 'libis/tools/extend/hash'

require 'libis/workflow/config'
require 'libis/workflow/status'
require_relative 'logging'

module Libis
  module Workflow
    module Base

      # Base module for all work items.
      #
      # This module lacks the implementation for the data attributes. It functions as an interface that describes the
      # common functionality regardless of the storage implementation. These attributes require some implementation:
      #
      # - status: [Symbol] the status field. Each task sets the status of the items it works on. Before starting processing
      #     the status is set to "#{task_name}Started". After successfull processing it is set to "#{task_name}Done" and if
      #     the task failed, it is set to "#{task_name}Failed". The status field can be used to perform real-time
      #     monitoring, reporting and error-recovery or restart of the ingest.
      #     The initial value for this attribute is :START.
      # - parent: [Object|nil] a link to a parent work item. Work items can be organized in any hierarchy you think is
      #     relevant for your workflow (e.g. directory[/directory...]/file/line or library/section/book/page). Of course
      #     hierarchies are not mandatory.
      # - items: [Array] a list of child work items. see above.
      # - options: [Hash] a set of options for the task chain on how to deal with this work item. This attribute can be
      #     used to fine-tune the behaviour of tasks for a particular work item.
      # - properties: [Hash] a set of properties, typically collected during the workflow processing and used to store
      #     final or intermediate resulst of tasks. The ::Lias::Ingester::FileItem module uses this attribute to store the
      #     properties (e.g. size, checksum, ...) of the file it represents.
      # - log_history: [Array] a list of all logging messages collected for this work item. Whenever a task logs a message
      #     it will automatically be registered for the work item that it is processing or for the work item that was
      #     supplied as the first argument.
      # - status_log: [Array] a list of all status changes the work item went through.
      # - summary: [Hash] collected statistics about the ingest for the work item and its children. This structure will
      #     be filled in by the included task ::Lias::Ingester::Tasks::Analyzer wich is appended to the workflow by default.
      #
      # The module is created so that it is possible to implement an ActiveRecord/Datamapper/... implementation easily.
      # A simple in-memory implementation would require:
      #
      # attr_accessor :parent
      # attr_accessor :items
      # attr_accessor :options, :properties
      # attr_accessor :log_history, :status_log
      # attr_accessor :summary
      #
      # def initialize
      #   self.parent = nil
      #   self.items = []
      #   self.options = {}
      #   self.properties = {}
      #   self.log_history = []
      #   self.status_log = []
      #   self.summary = {}
      # end
      #
      # protected
      #
      # ## Methods below should be adapted to match the implementation of the log arrays
      #
      # def add_log_entry(msg)
      #   self.log_history << msg.merge(c_at: ::Time.now)
      # end
      #
      # def add_status_log(message, tasklist = nil)
      #   self.status_log << { c_at: ::Time.now, tasklist: tasklist, text: message }.cleanup
      # end
      #
      #
      module WorkItem
        include Enumerable
        include Libis::Workflow::Status
        include Libis::Workflow::Base::Logging

        # String representation of the identity of the work item.
        #
        # You may want to overwrite this method as it tries the :name property or whatever #inspect returns if that
        # failes. Typically this should return the key value, file name or id number. If that's what your :name property
        # contains, you're fine.
        #
        # @return [String] string identification for this work item.
        def name
          # noinspection RubyResolve
          self.properties[:name] || self.inspect
        end

        def to_s;
          self.name;
        end

        def names
          (self.parent.names rescue Array.new).push(name).compact
        end

        def namepath;
          self.names.join('/');
        end

        # File name safe version of the to_s output.
        #
        # The output should be safe to use as a file name to store work item
        # data. Typical use is when extra file items are created by a task and need to be stored on disk. The default
        # implementation URL-encodes (%xx) all characters except alphanumeric, '.' and '-'.
        #
        # @return [String] file name
        def to_filename
          self.to_s.gsub(/[^\w.-]/) { |s| '%%%02x' % s.ord }
        end

        # Iterates over the work item clients and invokes code on each of them.
        def each
          self.items.each { |item| yield item }
        end

        # Add a child work item
        #
        # @param [WorkItem] item to be added to the child list :items
        def add_item(item)
          return self unless item and item.is_a? WorkItem
          self.items << item
          item.parent = self
          self.save!
          item.save!
          self
        end

        alias :<< :add_item

        # Dummy method. It is a placeholder for DB backed implementations. Wherever appropriate WorkItem#save will be
        # called to save the current item's state. If state needs to persisted, you should override this method or make
        # sure your persistence layer implements it in your class.
        def save
        end

        # Dummy method. It is a placeholder for DB backed implementations. Wherever appropriate WorkItem#save will be
        # called to save the current item's state. If state needs to persisted, you should override this method or make
        # sure your persistence layer implements it in your class.
        def save!
        end

        protected

        # go up the hierarchy and return the topmost work item
        #
        # @return [WorkItem] the root work item
        def root
          root = self
          root = root.parent while root.parent and root.parent.is_a? WorkItem
          root
        end

      end

    end
  end
end
