lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'libis/workflow/version'
require 'date'

Gem::Specification.new do |spec|
  spec.name = 'libis-workflow'
  spec.version = ::Libis::Workflow::VERSION
  spec.date = Date.today.to_s

  spec.summary = 'LIBIS Workflow framework.'
  spec.description = 'A simple framework to build custom task/workflow solutions.'

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

  spec.add_runtime_dependency 'libis-tools', '~> 1.1'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'awesome_print'
end
