# encoding: utf-8

module Libis
  class WorkflowError < ::RuntimeError
  end
  class WorkflowAbort < ::RuntimeError
  end
end
