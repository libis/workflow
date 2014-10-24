# encoding: utf-8

require 'rspec'
require 'stringio'

require 'LIBIS_Workflow'

require_relative 'spec_helper'

describe 'TestWorkflow' do

  DIRNAME = File.absolute_path(File.join(File.dirname(__FILE__), 'items'))

  before :all do
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
                name: 'ProcessFiles',
                subitems: true,
                recursive: false,
                tasks: [
                    {class: 'ChecksumTester', recursive: true},
                    {class: 'CamelizeName', recursive: true}
                ]
            }
        ],
        run_object: 'TestRun',
        input: {
            dirname: {default: '.', propagate_to: 'CollectFiles#location'},
            checksum_type: {default: 'SHA1', propagate_to: 'ChecksumTester'}
        }
    )

    # noinspection RubyStringKeysInHashInspection
    @run = @workflow.run(dirname: DIRNAME, checksum_type: 'SHA256')
    puts @logoutput.string

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

    expect(@run.items.first.name).to eq 'Items'

    @run.items.first.each_with_index do |x, i|
      expect(x.name).to eq %w'TestDirItem.rb TestFileItem.rb TestRun.rb'[i]
    end
  end

  it 'should return expected debug output' do

    sample_out = <<STR
DEBUG -- CollectFiles - TestRun : Started
DEBUG -- CollectFiles - TestRun : Processing subitem (1/1): items
DEBUG -- CollectFiles - items : Started
DEBUG -- CollectFiles - items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- CollectFiles - items/test_dir_item.rb : Started
DEBUG -- CollectFiles - items/test_dir_item.rb : Completed
DEBUG -- CollectFiles - items : Processing subitem (2/3): test_file_item.rb
DEBUG -- CollectFiles - items/test_file_item.rb : Started
DEBUG -- CollectFiles - items/test_file_item.rb : Completed
DEBUG -- CollectFiles - items : Processing subitem (3/3): test_run.rb
DEBUG -- CollectFiles - items/test_run.rb : Started
DEBUG -- CollectFiles - items/test_run.rb : Completed
DEBUG -- CollectFiles - items : 3 of 3 subitems passed
DEBUG -- CollectFiles - items : Completed
DEBUG -- CollectFiles - TestRun : 1 of 1 subitems passed
DEBUG -- CollectFiles - TestRun : Completed
DEBUG -- ProcessFiles - TestRun : Started
DEBUG -- ProcessFiles - TestRun : Processing subitem (1/1): items
DEBUG -- ProcessFiles - items : Started
DEBUG -- ProcessFiles - items : Running subtask (1/2): ChecksumTester
DEBUG -- ProcessFiles/ChecksumTester - items : Started
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- ProcessFiles/ChecksumTester - items/test_dir_item.rb : Started
DEBUG -- ProcessFiles/ChecksumTester - items/test_dir_item.rb : Completed
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (2/3): test_file_item.rb
DEBUG -- ProcessFiles/ChecksumTester - items/test_file_item.rb : Started
DEBUG -- ProcessFiles/ChecksumTester - items/test_file_item.rb : Completed
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (3/3): test_run.rb
DEBUG -- ProcessFiles/ChecksumTester - items/test_run.rb : Started
DEBUG -- ProcessFiles/ChecksumTester - items/test_run.rb : Completed
DEBUG -- ProcessFiles/ChecksumTester - items : 3 of 3 subitems passed
DEBUG -- ProcessFiles/ChecksumTester - items : Completed
DEBUG -- ProcessFiles - items : Running subtask (2/2): CamelizeName
DEBUG -- ProcessFiles/CamelizeName - items : Started
DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- ProcessFiles/CamelizeName - Items/test_dir_item.rb : Started
DEBUG -- ProcessFiles/CamelizeName - Items/TestDirItem.rb : Completed
DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (2/3): test_file_item.rb
DEBUG -- ProcessFiles/CamelizeName - Items/test_file_item.rb : Started
DEBUG -- ProcessFiles/CamelizeName - Items/TestFileItem.rb : Completed
DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (3/3): test_run.rb
DEBUG -- ProcessFiles/CamelizeName - Items/test_run.rb : Started
DEBUG -- ProcessFiles/CamelizeName - Items/TestRun.rb : Completed
DEBUG -- ProcessFiles/CamelizeName - Items : 3 of 3 subitems passed
DEBUG -- ProcessFiles/CamelizeName - Items : Completed
DEBUG -- ProcessFiles - Items : Completed
DEBUG -- ProcessFiles - TestRun : 1 of 1 subitems passed
DEBUG -- ProcessFiles - TestRun : Completed
STR
    sample_out = sample_out.lines.to_a
    output = @logoutput.string.lines

    expect(sample_out.count).to eq output.count
    output.each_with_index do |o, i|
      expect(o[/(?<=\] ).*/]).to eq sample_out[i].strip
    end

    expect(@run.summary['DEBUG']).to eq 48
    expect(@run.log_history.count).to eq 8
    expect(@run.status_log.count).to eq 6
    expect(@run.items.first.log_history.count).to eq 22
    expect(@run.items.first.status_log.count).to eq 8

    [
        {tasklist: nil, text: :STARTED},
        {tasklist: %w'CollectFiles', text: :Started},
        {tasklist: %w'CollectFiles', text: :Done},
        {tasklist: %w'ProcessFiles', text: :Started},
        {tasklist: %w'ProcessFiles', text: :Done},
        {tasklist: nil, :text => :DONE},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(@run.status_log[i][key]).to eq h[key] }
    end

    [
        {tasklist: %w'CollectFiles', text: :Started},
        {tasklist: %w'CollectFiles', text: :Done},
        {tasklist: %w'ProcessFiles', text: :Started},
        {tasklist: %w'ProcessFiles ChecksumTester', text: :Started},
        {tasklist: %w'ProcessFiles ChecksumTester', text: :Done},
        {tasklist: %w'ProcessFiles CamelizeName', text: :Started},
        {tasklist: %w'ProcessFiles CamelizeName', text: :Done},
        {tasklist: %w'ProcessFiles', text: :Done},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(@run.items.first.status_log[i][key]).to eq h[key] }
    end

    [
        {tasklist: %w'CollectFiles', text: :Started},
        {tasklist: %w'CollectFiles', text: :Done},
        {tasklist: %w'ProcessFiles ChecksumTester', text: :Started},
        {tasklist: %w'ProcessFiles ChecksumTester', text: :Done},
        {tasklist: %w'ProcessFiles CamelizeName', text: :Started},
        {tasklist: %w'ProcessFiles CamelizeName', text: :Done},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(@run.items.first.first.status_log[i][key]).to eq h[key] }
    end

    [
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: 'Started'},
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: 'Processing subitem (1/1): items'},
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: '1 of 1 subitems passed'},
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: 'Completed'},
        {severity: 'DEBUG', task: 'ProcessFiles', id: 0, message: 'Started'},
        {severity: 'DEBUG', task: 'ProcessFiles', id: 0, message: 'Processing subitem (1/1): items'},
        {severity: 'DEBUG', task: 'ProcessFiles', id: 0, message: '1 of 1 subitems passed'},
        {severity: 'DEBUG', task: 'ProcessFiles', id: 0, message: 'Completed'},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(@run.log_history[i][key]).to eq h[key] }
    end

    [
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: 'Started'},
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: 'Processing subitem (1/3): test_dir_item.rb'},
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: 'Processing subitem (2/3): test_file_item.rb'},
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: 'Processing subitem (3/3): test_run.rb'},
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: '3 of 3 subitems passed'},
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: 'Completed'},
        {severity: 'DEBUG', task: 'ProcessFiles', id: 0, message: 'Started'},
        {severity: 'DEBUG', task: 'ProcessFiles', id: 0, message: 'Running subtask (1/2): ChecksumTester'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', id: 0, message: 'Started'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', id: 0, message: 'Processing subitem (1/3): test_dir_item.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', id: 0, message: 'Processing subitem (2/3): test_file_item.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', id: 0, message: 'Processing subitem (3/3): test_run.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', id: 0, message: '3 of 3 subitems passed'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', id: 0, message: 'Completed'},
        {severity: 'DEBUG', task: 'ProcessFiles', id: 0, message: 'Running subtask (2/2): CamelizeName'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', id: 0, message: 'Started'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', id: 0, message: 'Processing subitem (1/3): test_dir_item.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', id: 0, message: 'Processing subitem (2/3): test_file_item.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', id: 0, message: 'Processing subitem (3/3): test_run.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', id: 0, message: '3 of 3 subitems passed'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', id: 0, message: 'Completed'},
        {severity: 'DEBUG', task: 'ProcessFiles', id: 0, message: 'Completed'},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(@run.items.first.log_history[i][key]).to eq h[key] }
    end

    [
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: 'Started'},
        {severity: 'DEBUG', task: 'CollectFiles', id: 0, message: 'Completed'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', id: 0, message: 'Started'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', id: 0, message: 'Completed'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', id: 0, message: 'Started'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', id: 0, message: 'Completed'},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(@run.items.first.first.log_history[i][key]).to eq h[key] }
    end

  end

end