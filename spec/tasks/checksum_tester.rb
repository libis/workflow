# encoding: utf-8
require 'digest'

require 'libis/exceptions'
require 'libis/workflow/workitems'

class ChecksumTester < ::LIBIS::Workflow::Task

  def self.default_options
    {checksum_type: 'MD5'}
  end

  def process
    return unless item_type? TestFileItem

    case self.options[:checksum_type]
      when 'MD5'
        checksum = ::Digest::MD5.hexdigest(File.read(workitem.long_name))
        raise ::LIBIS::WorkflowError, "Checksum test failed for #{workitem.long_name}" unless workitem.properties[:checksum] == checksum
      when 'SHA1'
        checksum = ::Digest::SHA1.hexdigest(File.read(workitem.long_name))
        raise ::LIBIS::WorkflowError, "Checksum test failed for #{workitem.long_name}" unless workitem.properties[:checksum] == checksum
      when 'SHA2'
        checksum = ::Digest::SHA2.new(256).hexdigest(File.read(workitem.long_name))
        raise ::LIBIS::WorkflowError, "Checksum test failed for #{workitem.long_name}" unless workitem.properties[:checksum] == checksum
      else
        # do nothing
        warn "Checksum type '#{self.options[:checksum_type]}' not supported. Check ignored."
    end

  end
end
