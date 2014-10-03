# encoding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'libis/workflow/version'

Gem::Specification.new do |gem|
  gem.name = 'LIBIS_Workflow'
  gem.version = ::LIBIS::Workflow::VERSION
  gem.date = Date.today.to_s

  gem.summary = %q{LIBIS Workflow framework.}
  gem.description = %q{A simple custom task/workflow framework.}

  gem.author = 'Kris Dekeyser'
  gem.email = 'kris.dekeyser@libis.be'
  gem.homepage = 'https://github.com/Kris-LIBIS/workflow'
  gem.license = 'MIT'

  gem.files = `git ls-files -z`.split("\x0")
  gem.executables = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files = gem.files.grep(%r{^(test|spec|features)/})

  gem.require_paths = ['lib']

  gem.add_runtime_dependency 'backports'
  gem.add_runtime_dependency 'sidekiq'
  gem.add_runtime_dependency 'LIBIS_Tools', '0.0.1'

  gem.add_development_dependency 'bundler', '~> 1.6'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'coveralls'

end
