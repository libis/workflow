# encoding: utf-8
require 'libis/tools/checksum'

require 'libis/workflow/workitems'

class TestFileItem
  include ::Libis::Workflow::FileItem

  def filename=(file)
    raise RuntimeError, "'#{file}' is not a file" unless File.file? file
    set_checksum :SHA256, ::Libis::Tools::Checksum.hexdigest(file, :SHA256)
    super file
  end

  def name
    self.properties[:name] || super
  end

end