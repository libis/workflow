module Libis
  module Workflow
    VERSION = '3.0.0' unless const_defined? :VERSION # the guard is against a redefinition warning that happens on Travis
  end
end
