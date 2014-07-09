# encoding: utf-8

require File.expand_path(File.join(File.dirname(__FILE__), 'lib/libis/workflow/version'))

Gem::Specification.new do |gem|
  gem.name = 'LIBIS_Worfklow'
  gem.version = ::LIBIS::Workflow::VERSION
  gem.date = Date.today.to_s

  gem.summary = %q{LIBIS Workflow framework.}
  gem.description = %q{A simple custom task/workflow framework.}

  gem.author = 'Kris Dekeyser'
  gem.email = 'kris.dekeyser@libis.be'
  gem.homepage = 'https://github.com/libis/workflow'
  gem.license = 'MIT'

  gem.files = `git ls-files -z`.split("\0")
  gem.executables = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files = gem.files.grep(%r{^(test|spec|features)/})

  gem.require_paths = ['lib']

  gem.add_development_dependency 'bundler', '~> 1.6'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'

  gem.add_runtime_dependency 'backports'

end
