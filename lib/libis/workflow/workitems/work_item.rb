# encoding: utf-8

require 'backports/rails/hash'

require 'libis/workflow/config'

module LIBIS
  module Workflow

    # Base class for all work items.
    #
    # This class contains some basic attributes required for making the workflow and tasks behave properly:
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
    # The class is created so that it is possible to derive an ActiveRecord/Datamapper/Mongoid/... implementation easily.

    module WorkItem
      include Enumerable

      attr_accessor :parent
      attr_accessor :items
      attr_accessor :options, :properties
      attr_accessor :log_history, :status_log
      attr_accessor :summary

      # The initializer takes care of properly setting the correct default values for the attributes. A derived class
      # that wishes to define it's own initializer should take care to call 'super' or make sure it overwrites the
      # attribute definitions itself. (e.g. in a ActiveRecord implementation)
      def initialize
        self.parent = nil
        self.items = []
        self.options = {}
        self.properties = {}
        self.log_history = []
        self.status_log = []
        self.summary = {}
      end

      # String representation of the identity of the work item.
      #
      # You may want to overwrite this method as it tries to call the #name method and returns whatever #inspect returns
      # if that failes. Typically this should return the key value, file name or id number. If that's what your #name
      # method returns, you're fine.
      #
      # @return [String] string identification for this work item.
      def to_s
        self.name rescue self.inspect
      end

      # File name save version of the to_s output. The output should be safe to use as a file name to store work item
      # data. Typical use is when extra file items are created by a task and need to be stored on disk. The default
      # implementation URL-encodes (%xx) all characters except alphanumeric, '.' and '-'.
      #
      # @return [String] file name
      def to_filename
        self.to_s.gsub(/[^\w.-]/) { |s| '%%%02x' % s.ord }
      end

      # Changes the status of the object. As a side effect the status is also logged in the status_log with the current
      # timestamp.
      #
      # @param [Symbol] s
      def status=(s)
        if s != self.status
          self.status_log << {
              timestamp: ::Time.now,
              text: s
          }
          self.status = s
          self.save
        end
      end


      def status
        self.status_log.last[:text] rescue :START
      end

      # Check ingest status of the object. The status is checked to see if it ends in 'Failed'.
      #
      # @return [Boolean] true if the object failed, false otherwise
      def failed?
        self.status.to_s =~ /Failed$/ ? true : false
      end

      # Helper function for the Tasks to add a log entry to the log_history.
      #
      # The supplied message structure is expected to contain the following fields:
      # - :severity : ::Logger::Severity value
      # - :id : optional message id
      # - :test : message text
      # - :names : list of tasks names (task hierarchy) that submits the message
      #
      # @param [Hash] message
      def add_log(message = {})
        msg = message_struct(message)
        self.log_history << msg
        self.save
      end

      alias :<= :add_log

      # Iterates over the work item clients and invokes code on each of them.
      #
      # @param [Proc] block procedure that will be invoked for each item. The block gets the item as parameter.
      def each(&block)
        self.items.each { |item| block.call(item) }
      end

      # Add a child work item
      #
      # @param [WorkItem] item to be added to the child list :items
      def add_item(item)
        return unless item and item.is_a? WorkItem
        self.items << item
        item.parent = self
        self.save
        item.save
      end

      alias :<< :add_item

      # Dummy method. It is a placeholder for DB backed implementations. Wherever appropriate WorkItem#save will be
      # called to save the current item's state. If state needs to persisted, you should override this method or make
      # sure your persistence layer implements it in your class.
      def save
      end

      protected

      SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY) unless const_defined? :SEV_LABEL

      # create and return a proper message structure
      def message_struct(opts = {})
        opts.reverse_merge!(severity: ::Logger::INFO, id: 0, text: '')
        {
            timestamp: ::Time.now,
            severity: SEV_LABEL[opts[:severity]],
            task_list: opts[:names],
            message: opts[:text]
        }
      end

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
