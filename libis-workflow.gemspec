# frozen_string_literal: true

require 'date'
require File.join(__dir__,'lib/libis/workflow/version')

Gem::Specification.new do |spec|
  spec.name = 'libis-workflow'
  spec.version = Libis::Workflow::VERSION
  spec.date = Date.today.to_s

  spec.summary = 'LIBIS Workflow framework.'
  spec.description = 'A simple framework to build custom workflow solutions.'

  spec.author = 'Kris Dekeyser'
  spec.email = 'kris.dekeyser@libis.be'
  spec.homepage = 'https://github.com/Kris-LIBIS/workflow'
  spec.license = 'MIT'

  if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
    spec.platform = Gem::Platform::JAVA
  end

  spec.files = `git ls-files -z`.split("\x0")
  spec.executables = spec.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})

  spec.require_paths = ['lib']

  spec.add_development_dependency 'awesome_print', '~> 1.8'
  spec.add_development_dependency 'coveralls', '~> 0.7'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'simplecov', '~> 0.17'

  spec.add_runtime_dependency 'libis-tools', '~> 1.0'
  spec.add_runtime_dependency 'ruby-enum', '~> 0.7'
end
