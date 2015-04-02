require 'libis/tools/logger'

module Libis
  module Workflow
    module Base
      module Logger
        include ::Libis::Tools::Logger

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