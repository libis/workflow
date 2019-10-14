# frozen_string_literal: true

module Libis
  module Workflow

    # the guard is against a redefinition warning that happens on Travis
    VERSION = '3.0.beta.1' unless const_defined? :VERSION

  end
end
