# encoding: utf-8

module Libis
  module Workflow
    VERSION = '2.0.beta.20' unless const_defined? :VERSION # the guard is against a redefinition warning that happens on Travis
  end
end
