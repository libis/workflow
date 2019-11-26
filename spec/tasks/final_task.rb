# frozen_string_literal: true

require 'libis/exceptions'
require 'libis/workflow'

class FinalTask < ::Libis::Workflow::Task

  parameter run_always: false

  def run_always
    parameter(:run_always)
  end

  def configure(*args)
    super
  end

  protected

  def process(item, *_args)
    return unless item.is_a? TestFileItem

    info "Final processing of #{item.name}"
  end

end
