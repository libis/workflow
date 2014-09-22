# encoding: utf-8

require 'rspec'
require 'stringio'

require 'LIBIS_Workflow'

require_relative 'spec_helper'

describe 'TestWorkflow' do

  DIRNAME = 'spec/items'

  before do
    $:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

    @logoutput = StringIO.new

    ::LIBIS::Workflow.configure do |cfg|
      cfg.itemdir = File.join(File.dirname(__FILE__), 'items')
      cfg.taskdir = File.join(File.dirname(__FILE__), 'tasks')
      cfg.workdir = File.join(File.dirname(__FILE__), 'work')
      cfg.logger = Logger.new @logoutput
      cfg.logger.level = Logger::DEBUG
    end

    @workflow = ::LIBIS::Workflow::Workflow.new
    @workflow.configure(
        name: 'TestWorkflow',
        description: 'Workflow for testing',
        tasks: [
            {class: 'CollectFiles', recursive: true},
            {
                class: 'ProcessFiles',
                subitems: true,
                tasks: [
                    {class: 'ChecksumTester',  recursive: true},
                    {class: 'CamelizeName',  recursive: true}
                ]
            }
        ],
        run_object: 'TestRun',
        input: {
            dirname: {default: '.'}
        }
    )

    @run = @workflow.run(dirname: DIRNAME)

  end

  it 'should contain three tasks' do

    expect(@workflow.config[:tasks].size).to eq 3
    expect(@workflow.config[:tasks].first[:class]).to eq 'CollectFiles'
    expect(@workflow.config[:tasks].last[:class]).to eq '::LIBIS::Workflow::Tasks::Analyzer'

  end

  # noinspection RubyResolve
  it 'should camelize the workitem name' do

    expect(@run.options[:dirname]).to eq DIRNAME
    expect(@run.items.count).to eq 1
    expect(@run.items.first.class).to eq TestDirItem
    expect(@run.items.first.count).to eq 3
    expect(@run.items.first.first.class).to eq TestFileItem

    @run.items.first.each_with_index do |x, i|
      expect(x.name).to eq %w'Spec::Items::TestDirItem.rb Spec::Items::TestFileItem.rb Spec::Items::TestRun.rb'[i]
    end
  end

  it 'should return expected debug output' do

    sample_out = <<STR
DEBUG -- CollectFiles - TestRun : Started
DEBUG -- CollectFiles - TestRun : Processing subitem (1/1): items
DEBUG -- CollectFiles - items : Started
DEBUG -- CollectFiles - items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- CollectFiles - test_dir_item.rb : Started
DEBUG -- CollectFiles - test_dir_item.rb : Completed
DEBUG -- CollectFiles - items : Processing subitem (2/3): test_file_item.rb
DEBUG -- CollectFiles - test_file_item.rb : Started
DEBUG -- CollectFiles - test_file_item.rb : Completed
DEBUG -- CollectFiles - items : Processing subitem (3/3): test_run.rb
DEBUG -- CollectFiles - test_run.rb : Started
DEBUG -- CollectFiles - test_run.rb : Completed
DEBUG -- CollectFiles - items : 3 of 3 items passed
DEBUG -- CollectFiles - items : Completed
DEBUG -- CollectFiles - TestRun : 1 of 1 items passed
DEBUG -- CollectFiles - TestRun : Completed
DEBUG -- ProcessFiles - TestRun : Processing subitem (1/1): items
DEBUG -- ProcessFiles - items : Started
DEBUG -- ProcessFiles - items : Running subtask (1/2): ChecksumTester
DEBUG -- ProcessFiles/ChecksumTester - items : Started
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- ProcessFiles/ChecksumTester - test_dir_item.rb : Started
DEBUG -- ProcessFiles/ChecksumTester - test_dir_item.rb : Completed
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (2/3): test_file_item.rb
DEBUG -- ProcessFiles/ChecksumTester - test_file_item.rb : Started
DEBUG -- ProcessFiles/ChecksumTester - test_file_item.rb : Completed
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (3/3): test_run.rb
DEBUG -- ProcessFiles/ChecksumTester - test_run.rb : Started
DEBUG -- ProcessFiles/ChecksumTester - test_run.rb : Completed
DEBUG -- ProcessFiles/ChecksumTester - items : 3 of 3 items passed
DEBUG -- ProcessFiles/ChecksumTester - items : Completed
DEBUG -- ProcessFiles - items : Running subtask (2/2): CamelizeName
DEBUG -- ProcessFiles/CamelizeName - items : Started
DEBUG -- ProcessFiles/CamelizeName - Spec::Items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- ProcessFiles/CamelizeName - test_dir_item.rb : Started
DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestDirItem.rb : Completed
DEBUG -- ProcessFiles/CamelizeName - Spec::Items : Processing subitem (2/3): test_file_item.rb
DEBUG -- ProcessFiles/CamelizeName - test_file_item.rb : Started
DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestFileItem.rb : Completed
DEBUG -- ProcessFiles/CamelizeName - Spec::Items : Processing subitem (3/3): test_run.rb
DEBUG -- ProcessFiles/CamelizeName - test_run.rb : Started
DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestRun.rb : Completed
DEBUG -- ProcessFiles/CamelizeName - Spec::Items : 3 of 3 items passed
DEBUG -- ProcessFiles/CamelizeName - Spec::Items : Completed
DEBUG -- ProcessFiles - Spec::Items : Completed
DEBUG -- ProcessFiles - TestRun : 1 of 1 items passed
STR
    sample_out = sample_out.lines.to_a
    output = @logoutput.string.lines

    expect(sample_out.count).to eq output.count
    output.each_with_index do |o, i|
      expect(o[/(?<=\] ).*/]).to eq sample_out[i].strip
    end

    expect(@run.summary['DEBUG']).to eq 46
    expect(@run.log_history.count).to eq 6
    expect(@run.status_log.count).to eq 6
    expect(@run.items.first.log_history.count).to eq 22
    expect(@run.items.first.status_log.count).to eq 8

  end

end