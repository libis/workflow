# encoding: utf-8

module LIBIS
  class WorkflowError < ::RuntimeError
  end
  class WorkflowAbort < ::RuntimeError
  end
end
