# frozen_string_literal: true

module Libis

  class WorkflowInterrupt < ::RuntimeError
  end
  class WorkflowError < ::RuntimeError
  end
  class WorkflowAbort < ::RuntimeError
  end

end
