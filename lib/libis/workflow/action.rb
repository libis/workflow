# frozen_string_literal: true
require 'ruby-enum'

module Libis
  module Workflow
    class Action

      define :run, 'run'
      define :continue, 'continue'
      define :retry, 'retry'
      define :undo, 'undo'
      define :abort, 'abort'

    end
  end
end
