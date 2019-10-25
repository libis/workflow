# frozen_string_literal: true

require_relative 'test_work_item'

class TestFileItem < TestWorkItem

  include Libis::Workflow::FileItem

  def filename=(file)
    raise "'#{file}' is not a file" unless File.file? file

    super

    set_checksum :SHA256, ::Libis::Tools::Checksum.hexdigest(file, :SHA256)
  end

end
