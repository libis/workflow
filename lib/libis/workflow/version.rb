module Libis
  module Workflow
    VERSION = '2.1.9' unless const_defined? :VERSION # the guard is against a redefinition warning that happens on Travis
  end
end
