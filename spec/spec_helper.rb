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

require_relative 'tasks/camelize_name'
require_relative 'tasks/checksum_tester'
require_relative 'tasks/collect_files'
require_relative 'tasks/final_task'
require_relative 'tasks/processing_task'


RSpec.configure do |config|

  config.before(:each) do
    # noinspection RubyResolve
    ::Libis::Workflow.configure do |cfg|
      @basedir = File.absolute_path File.join(__dir__)
      @dirname = File.join(@basedir, 'items')
      @datadir = File.join(@basedir, 'data')

      cfg.itemdir = @dirname
      cfg.taskdir = File.join(@basedir, 'tasks')
      cfg.workdir = File.join(@basedir, 'work')
      cfg.status_log = TestStatusLog
      cfg.logger.appenders =
          ::Logging::Appenders.string_io('StringIO', layout: ::Libis::Tools::Config.get_log_formatter,
                                         level: debug_level || :INFO)
       #cfg.logger.add_appenders ::Logging::Appenders.stdout('StdOut', layout: ::Libis::Tools::Config.get_log_formatter,
       #                                                     level: :DEBUG)
      Libis::Workflow::Config.require_all cfg.itemdir
      Libis::Workflow::Config.require_all cfg.taskdir
      Libis::Workflow::Config.require_all cfg.workdir

      TestStatusLog.registry.clear
    end
  end

end

