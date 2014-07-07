# encoding: utf-8

require 'logger'

require 'backports/rails/string'

require 'libis/workflow/message_registry'
require 'libis/workflow/workitems/work_item'
require 'libis/workflow/exception'
require 'libis/workflow/config'

module LIBIS
  module Workflow

    module Base

      #noinspection RubyResolve
      attr_reader :parent, :workitem, :name, :action

      def set_parent(p)
        @parent = p
      end

      def names
        (self.parent.names rescue Array.new).push(name).compact
      end

      def debug(msg, *args)
        return if (self.options[:quiet] rescue false)
        message ::Logger::DEBUG, msg, *args
      end

      def info(msg, *args)
        return if (self.options[:quiet] rescue false)
        message ::Logger::INFO, msg, *args
      end

      def warn(msg, *args)
        return if (self.options[:quiet] rescue false)
        message ::Logger::WARN, msg, *args
      end

      def error(msg, *args)
        message ::Logger::ERROR, msg, *args
      end

      def fatal(msg, *args)
        message ::Logger::FATAL, msg, *args
      end

      def message (severity, msg, *args)
        log_message severity, to_msg(msg), *args
      end

      def to_status(text)
        ((name || parent.name + 'Worker') + text.to_s.capitalize).to_sym
      end

      def check_item_type(klass, item = nil)
        item ||= @workitem
        unless item.is_a? klass.to_s.constantize
          raise RuntimeError, "Workitem is of wrong type : #{item.class} - expected #{klass.to_s}"
        end
      end

      def item_type?(klass, item = nil)
        item ||= @workitem
        item.is_a? klass.to_s.constantize
      end

      private

      def to_msg(msg)
        case msg
          when String
            {text: msg}
          when Integer
            {id: msg}
          else
            {text: (msg.to_s rescue '')}
        end
      end

      def log_message(severity, msg, *args)
        # Prepare info from msg struct for use with string substitution
        message_id, message_text = if msg[:id]
                                     [msg[:id], MessageRegistry.instance.get_message(msg[:id])]
                                   elsif msg[:text]
                                     [0, msg[:text]]
                                   else
                                     [0, '']
                                   end

        item = @workitem
        item = args.shift if args.size > 0 and args[0].is_a?(WorkItem)

        # Support for named substitutions
        args = args[0] if message_text.match(/%\{\w*}/) and args.is_a? Array and args.size == 1 and args[0].is_a? Hash

        message_text = (message_text % args rescue ((message_text + ' - %s') % args.to_s))

        process_message(severity, message_id.to_i, message_text, item)

        Config.logger.add(severity, message_text, '%s - %s ' % [self.names.join('/'), (item.to_string rescue '')])
      end

      def process_message(severity, message_id, message_text, item)
        return unless item and item.respond_to? :add_log
        item.add_log(
            severity: severity,
            id: message_id,
            text: message_text,
            names: self.names
        )
      end

    end

  end
end
