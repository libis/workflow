# frozen_string_literal: true

require 'libis/tools/checksum'

require 'libis/exceptions'
require 'libis/workflow'

class ChecksumTester < ::Libis::Workflow::Task

  parameter checksum_type: nil,
            description: 'Checksum type to use.',
            constraint: ::Libis::Tools::Checksum::CHECKSUM_TYPES.map(&:to_s)

  def process(item)
    return unless item.is_a? TestFileItem

    checksum_type = parameter(:checksum_type)

    if checksum_type.nil?
      ::Libis::Tools::Checksum::CHECKSUM_TYPES.each do |x|
        test_checksum(item, x) if item.checksum(x)
      end
    else
      test_checksum(item, checksum_type)
    end
  end

  def test_checksum(item, checksum_type)
    checksum = ::Libis::Tools::Checksum.hexdigest(item.fullpath, checksum_type.to_sym)
    return if item.checksum(checksum_type) == checksum

    raise ::Libis::WorkflowError, "Checksum test #{checksum_type} failed for #{item.filepath}"
  end

end
