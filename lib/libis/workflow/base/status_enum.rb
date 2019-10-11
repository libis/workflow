# frozen_string_literal: true

module Libis::Workflow::Base
  class StatusEnum
    include Ruby::Enum

    define :not_started, 'not started'
    define :not_started, 'reverted'
    define :started, 'started'
    define :running, 'running'
    define :reverting, 'reverting'
    define :async_wait, 'async process running'
    define :reverted, 'reverted'
    define :done, 'done'
    define :async_halt, 'async process failed'
    define :failed, 'failed'

    def self.to_sym(status)
      case status
      when Symbol
        status
      when Integer
        keys[status]
      else # String
        key(status)
      end
    end

    def self.to_str(status)
      case status
      when String
        status
      when Integer
        values[status]
      else # Symbol
        value(status)
      end
    end

    def self.to_int(status)
      case status
      when Integer
        status
      when Symbol
        keys.index_of(status)
      else # String
        values.index_of(status)
      end
    end
  end
end
