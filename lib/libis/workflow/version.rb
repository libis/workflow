# encoding: utf-8

module LIBIS
  module Workflow
    VERSION = '0.1.1' unless const_defined? :VERSION # the guard is against a redefinition warning that happens on Travis
  end
end