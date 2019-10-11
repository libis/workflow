# frozen_string_literal: true

require 'libis/tools/config'

module Libis::Workflow
  # noinspection RubyConstantNamingConvention
  Config = ::Libis::Tools::Config

  Config.define_singleton_method(:require_all) do |dir|
    Dir.glob(File.join(dir, '*.rb')).each do |filename|
      # noinspection RubyResolve
      require filename
    end
  end

  # Config[:workdir] = './work'
  # Config[:taskdir] = './tasks'
  # Config[:itemdir] = './items'
end
