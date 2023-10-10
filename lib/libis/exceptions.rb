module Libis
  class WorkflowError < ::RuntimeError
  end
  class WorkflowAbort < ::RuntimeError
  end
  class WorkflowAbortForget < ::RuntimeError
  end
end
