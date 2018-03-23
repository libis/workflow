require 'libis/exceptions'
require 'libis/workflow'

class FinalTask < ::Libis::Workflow::Task

  def process(item)
    return unless item.is_a? TestFileItem

    info "Final processing of #{item.name}"

  end

end
