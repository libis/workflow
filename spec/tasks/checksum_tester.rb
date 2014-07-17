# encoding: utf-8
require 'digest'

require 'libis/exceptions'
require 'libis/workflow/workitems'

class ChecksumTester < ::LIBIS::Workflow::Task
  def process
    check_item_type ::LIBIS::Workflow::FileItem

    md5sum = ::Digest::MD5.hexdigest(File.read(workitem.filename))

    raise ::LIBIS::WorkflowError "Checksum test failed for #{workitem.filename}" unless workitem.properties[:checksum] == md5sum
  end
end
