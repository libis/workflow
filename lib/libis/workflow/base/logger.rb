require 'LIBIS_Tools'

module LIBIS
  module Workflow
    module Base
      module Logger
        include ::LIBIS::Tools::Logger

        # protected
        #
        # def debug(msg, *args)
        #   return if (self.options[:quiet] rescue false)
        #   message ::Logger::DEBUG, msg, *args
        # end
        #
        # def info(msg, *args)
        #   return if (self.options[:quiet] rescue false)
        #   message ::Logger::INFO, msg, *args
        # end
        #
        # def warn(msg, *args)
        #   return if (self.options[:quiet] rescue false)
        #   message ::Logger::WARN, msg, *args
        # end
        #
        # def error(msg, *args)
        #   message ::Logger::ERROR, msg, *args
        # end
        #
        # def fatal(msg, *args)
        #   message ::Logger::FATAL, msg, *args
        # end
        #
        # private
        #

        def message(severity, msg, *args)
          item = self.workitem
          item = args.shift if args.size > 0 and args[0].is_a?(WorkItem)

          item.log_message(severity, to_msg(msg), *args) if item
        end

        def to_msg(msg)
          case msg
            when String
              {text: msg}
            when Integer
              {id: msg}
            else
              {text: (msg.to_s rescue '')}
          end.merge task: self.namepath
        end

      end
    end
  end
end