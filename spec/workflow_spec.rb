require_relative 'spec_helper'

require 'stringio'

describe 'TestWorkflow' do

  let(:basedir) { File.absolute_path File.join(File.dirname(__FILE__)) }
  let(:dirname) { File.join(basedir, 'items') }

  let(:logoutput) { StringIO.new }

  let(:workflow) {
    # noinspection RubyResolve
    ::Libis::Workflow.configure do |cfg|
      cfg.itemdir = dirname
      cfg.taskdir = File.join(basedir, 'tasks')
      cfg.workdir = File.join(basedir, 'work')
      cfg.logger = Logger.new logoutput
      cfg.logger.level = Logger::DEBUG
    end

    workflow = ::Libis::Workflow::Workflow.new
    workflow.configure(
        name: 'TestWorkflow',
        description: 'Workflow for testing',
        tasks: [
            {class: 'CollectFiles', recursive: true},
            {
                name: 'ProcessFiles', subitems: true, recursive: false,
                tasks: [
                    {class: 'ChecksumTester', recursive: true},
                    {class: 'CamelizeName', recursive: true}
                ]
            }
        ],
        input: {
            dirname: {default: '.', propagate_to: 'CollectFiles#location'},
            checksum_type: {default: 'SHA1', propagate_to: 'ChecksumTester'}
        }
    )
    workflow
  }

  let(:job) {
    job = ::Libis::Workflow::Job.new
    job.configure(
        name: 'TestJob',
        description: 'Job for testing',
        workflow: workflow,
        run_object: 'TestRun',
        input: {dirname: dirname, checksum_type: 'SHA256'},
    )
    job
  }

  let!(:run) {
    job.execute
  }

  it 'should contain three tasks' do
    expect(workflow.config[:tasks].size).to eq 3
    expect(workflow.config[:tasks].first[:class]).to eq 'CollectFiles'
    expect(workflow.config[:tasks].last[:class]).to eq '::Libis::Workflow::Tasks::Analyzer'
  end

  # noinspection RubyResolve
  it 'should camelize the workitem name' do
    expect(run.options[:dirname]).to eq dirname
    expect(run.items.count).to eq 1
    expect(run.items.first.class).to eq TestDirItem
    expect(run.items.first.count).to eq 3
    expect(run.items.first.first.class).to eq TestFileItem

    expect(run.items.first.name).to eq 'Items'

    run.items.first.each_with_index do |x, i|
      expect(x.name).to eq %w'TestDirItem.rb TestFileItem.rb TestRun.rb'[i]
    end
  end

  it 'should return expected debug output' do

    sample_out = <<STR
DEBUG -- CollectFiles - TestRun : Processing subitem (1/1): items
DEBUG -- CollectFiles - items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- CollectFiles - items : Processing subitem (2/3): test_file_item.rb
DEBUG -- CollectFiles - items : Processing subitem (3/3): test_run.rb
DEBUG -- CollectFiles - items : 3 of 3 subitems passed
DEBUG -- CollectFiles - TestRun : 1 of 1 subitems passed
DEBUG -- ProcessFiles - TestRun : Processing subitem (1/1): items
DEBUG -- ProcessFiles - items : Running subtask (1/2): ChecksumTester
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (2/3): test_file_item.rb
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (3/3): test_run.rb
DEBUG -- ProcessFiles/ChecksumTester - items : 3 of 3 subitems passed
DEBUG -- ProcessFiles - items : Running subtask (2/2): CamelizeName
DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (2/3): test_file_item.rb
DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (3/3): test_run.rb
DEBUG -- ProcessFiles/CamelizeName - Items : 3 of 3 subitems passed
DEBUG -- ProcessFiles - TestRun : 1 of 1 subitems passed
STR
    sample_out = sample_out.lines.to_a
    output = logoutput.string.lines.to_a

    expect(sample_out.count).to eq output.count
    output.each_with_index do |o, i|
      expect(o[/(?<=\] ).*/]).to eq sample_out[i].strip
    end

    expect(run.summary['DEBUG']).to eq 18
    expect(run.log_history.count).to eq 4
    expect(run.status_log.count).to eq 6
    expect(run.items.first.log_history.count).to eq 14
    expect(run.items.first.status_log.count).to eq 8

    [
        {tasklist: nil, text: :STARTED},
        {tasklist: %w'CollectFiles', text: :Started},
        {tasklist: %w'CollectFiles', text: :Done},
        {tasklist: %w'ProcessFiles', text: :Started},
        {tasklist: %w'ProcessFiles', text: :Done},
        {tasklist: nil, :text => :DONE},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(run.status_log[i][key]).to eq h[key] }
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
      h.keys.each { |key| expect(run.items.first.status_log[i][key]).to eq h[key] }
    end

    [
        {tasklist: %w'CollectFiles', text: :Started},
        {tasklist: %w'CollectFiles', text: :Done},
        {tasklist: %w'ProcessFiles ChecksumTester', text: :Started},
        {tasklist: %w'ProcessFiles ChecksumTester', text: :Done},
        {tasklist: %w'ProcessFiles CamelizeName', text: :Started},
        {tasklist: %w'ProcessFiles CamelizeName', text: :Done},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(run.items.first.first.status_log[i][key]).to eq h[key] }
    end

    [
        {severity: 'DEBUG', task: 'CollectFiles', message: 'Processing subitem (1/1): items'},
        {severity: 'DEBUG', task: 'CollectFiles', message: '1 of 1 subitems passed'},
        {severity: 'DEBUG', task: 'ProcessFiles', message: 'Processing subitem (1/1): items'},
        {severity: 'DEBUG', task: 'ProcessFiles', message: '1 of 1 subitems passed'},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(run.log_history[i][key]).to eq h[key] }
    end

    [
        {severity: 'DEBUG', task: 'CollectFiles', message: 'Processing subitem (1/3): test_dir_item.rb'},
        {severity: 'DEBUG', task: 'CollectFiles', message: 'Processing subitem (2/3): test_file_item.rb'},
        {severity: 'DEBUG', task: 'CollectFiles', message: 'Processing subitem (3/3): test_run.rb'},
        {severity: 'DEBUG', task: 'CollectFiles', message: '3 of 3 subitems passed'},
        {severity: 'DEBUG', task: 'ProcessFiles', message: 'Running subtask (1/2): ChecksumTester'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', message: 'Processing subitem (1/3): test_dir_item.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', message: 'Processing subitem (2/3): test_file_item.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', message: 'Processing subitem (3/3): test_run.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/ChecksumTester', message: '3 of 3 subitems passed'},
        {severity: 'DEBUG', task: 'ProcessFiles', message: 'Running subtask (2/2): CamelizeName'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', message: 'Processing subitem (1/3): test_dir_item.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', message: 'Processing subitem (2/3): test_file_item.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', message: 'Processing subitem (3/3): test_run.rb'},
        {severity: 'DEBUG', task: 'ProcessFiles/CamelizeName', message: '3 of 3 subitems passed'},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(run.items.first.log_history[i][key]).to eq h[key] }
    end

    # noinspection RubyResolve
    expect(run.items.first.first.log_history).to be_empty

  end

end