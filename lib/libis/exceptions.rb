# frozen_string_literal: true

module Libis

  class WorkflowError < ::RuntimeError
  end
  class WorkflowAbort < ::RuntimeError
  end

end
