# encoding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'libis/workflow/version'

Gem::Specification.new do |gem|
  gem.name = 'libis-workflow'
  gem.version = ::Libis::Workflow::VERSION
  gem.date = Date.today.to_s

  gem.summary = %q{LIBIS Workflow framework.}
  gem.description = %q{A simple framework to build custom task/workflow solutions.}

  gem.author = 'Kris Dekeyser'
  gem.email = 'kris.dekeyser@libis.be'
  gem.homepage = 'https://github.com/Kris-LIBIS/workflow'
  gem.license = 'MIT'

  gem.files = `git ls-files -z`.split("\x0")
  gem.executables = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files = gem.files.grep(%r{^(test|spec|features)/})

  gem.require_paths = ['lib']

  gem.add_development_dependency 'bundler', '~> 1.6'
  gem.add_development_dependency 'rake', '~> 10.3'
  gem.add_development_dependency 'rspec', '~> 3.1'
  gem.add_development_dependency 'simplecov', '~> 0.9'
  gem.add_development_dependency 'coveralls', '~> 0.7'

  gem.add_runtime_dependency 'libis-tools', '~> 0.9'
  gem.add_runtime_dependency 'sidekiq', '~> 3.3'

end
