require 'coveralls'
Coveralls.wear!

require 'bundler/setup'
Bundler.setup

require 'rspec'
require 'libis-workflow'
require_relative 'lib/test_workflow'
require_relative 'lib/test_job'
require_relative 'lib/test_run'
require_relative 'lib/test_status_log'