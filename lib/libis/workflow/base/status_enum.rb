# frozen_string_literal: true

require 'ruby-enum'

module Libis
  module Workflow
    module Base
      class StatusEnum

        include Ruby::Enum

        define :not_started, 'not started'
        define :started, 'started'
        define :running, 'running'
        define :reverting, 'reverting'
        define :async_wait, 'remote process running'
        define :reverted, 'reverted'
        define :done, 'done'
        define :async_halt, 'remote process failed'
        define :failed, 'failed'

        def self.failed?(status)
          [:async_halt, :failed].include?(status)
        end

        def self.success?(status)
          [:revered, :done].include? status
        end

        def self.busy?(status)
          [:started, :running, :reverting, :async_wait].include?(status)
        end

        def self.done?(status)
          [:reverted, :done, :async_halt, :failed].include?(status)
        end

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
            keys.index(status) || 0
          else # String
            values.index(status) || 0
          end
        end

      end
    end
  end
end
