# encoding: utf-8
require 'LIBIS_Tools'

require 'libis/workflow/workitems'

class TestFileItem
  include ::LIBIS::Workflow::FileItem

  def filename=(file)
    raise RuntimeError, "'#{file}' is not a file" unless File.file? file
    set_checksum :SHA256, ::LIBIS::Tools::Checksum.hexdigest(file, :SHA256)
    super file
  end

  def name
    self.properties[:name] || super
  end

end