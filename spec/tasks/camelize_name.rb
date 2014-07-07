# encoding: utf-8

require 'backports/rails/string'

require 'libis/workflow/workitems'

class CamelizeName < ::LIBIS::Workflow::Task
  def process
    #noinspection RubyResolve
    @workitem.name = @workitem.name.camelize
  end

end