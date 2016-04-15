require_relative 'spec_helper'

require 'stringio'

describe 'TestWorkflow' do

  basedir = File.absolute_path File.join(File.dirname(__FILE__))
  dirname = File.join(basedir, 'items')

  before :each do

    # noinspection RubyResolve
    ::Libis::Workflow.configure do |cfg|
      cfg.itemdir = dirname
      cfg.taskdir = File.join(basedir, 'tasks')
      cfg.workdir = File.join(basedir, 'work')
      cfg.logger.appenders =
          ::Logging::Appenders.string_io('StringIO', layout: ::Libis::Tools::Config.get_log_formatter)
    end
  end

  let(:logoutput) { ::Libis::Workflow::Config.logger.appenders.first.sio }

  let(:workflow) {
    workflow = ::Libis::Workflow::Workflow.new
    workflow.configure(
        'name' => 'TestWorkflow',
        'description' => 'Workflow for testing',
        'tasks' => [
            {'class' => 'CollectFiles', 'recursive' => true},
            {
                'name' => 'ProcessFiles', 'recursive' => false,
                'tasks' => [
                    {'class' => 'ChecksumTester', 'recursive' => true},
                    {'class' => 'CamelizeName', 'recursive' => true}
                ]
            }
        ],
        'input' => {
            'dirname' => {'default' => '.', 'propagate_to' => 'CollectFiles#location'},
            'checksum_type' => {'default' => 'SHA1', 'propagate_to' => 'ChecksumTester'}
        }
    )
    workflow
  }

  let(:job) {
    job = ::Libis::Workflow::Job.new
    job.configure(
        'name' => 'TestJob',
        'description' => 'Job for testing',
        'workflow' => workflow,
        'run_object' => 'TestRun',
        'input' => {'dirname' => dirname, 'checksum_type' => 'SHA256'},
    )
    job
  }

  it 'should contain three tasks' do
    expect(workflow.config['tasks'].size).to eq 2
    expect(workflow.config['tasks'].first['class']).to eq 'CollectFiles'
    expect(workflow.config['tasks'].last['name']).to eq 'ProcessFiles'
  end

  # noinspection RubyResolve
  it 'should camelize the workitem name' do
    run = job.execute
    expect(run.options['CollectFiles']['location']).to eq dirname
    expect(run.size).to eq 1
    expect(run.items.size).to eq 1
    expect(run.items.first.class).to eq TestDirItem
    expect(run.items.first.size).to eq 3
    expect(run.items.first.items.size).to eq 3
    expect(run.items.first.first.class).to eq TestFileItem

    expect(run.items.first.name).to eq 'Items'

    run.items.first.each_with_index do |x, i|
      expect(x.name).to eq %w'TestDirItem.rb TestFileItem.rb TestRun.rb'[i]
    end
  end

  it 'should return expected debug output' do

    sample_out = <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/2): CollectFiles
DEBUG -- CollectFiles - TestRun : Processing subitem (1/1): items
DEBUG -- CollectFiles - items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- CollectFiles - items : Processing subitem (2/3): test_file_item.rb
DEBUG -- CollectFiles - items : Processing subitem (3/3): test_run.rb
DEBUG -- CollectFiles - items : 3 of 3 subitems passed
DEBUG -- CollectFiles - TestRun : 1 of 1 subitems passed
 INFO -- Run - TestRun : Running subtask (2/2): ProcessFiles
 INFO -- ProcessFiles - TestRun : Running subtask (1/2): ChecksumTester
DEBUG -- ProcessFiles/ChecksumTester - TestRun : Processing subitem (1/1): items
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (2/3): test_file_item.rb
DEBUG -- ProcessFiles/ChecksumTester - items : Processing subitem (3/3): test_run.rb
DEBUG -- ProcessFiles/ChecksumTester - items : 3 of 3 subitems passed
DEBUG -- ProcessFiles/ChecksumTester - TestRun : 1 of 1 subitems passed
 INFO -- ProcessFiles - TestRun : Running subtask (2/2): CamelizeName
DEBUG -- ProcessFiles/CamelizeName - TestRun : Processing subitem (1/1): items
DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (1/3): test_dir_item.rb
DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (2/3): test_file_item.rb
DEBUG -- ProcessFiles/CamelizeName - Items : Processing subitem (3/3): test_run.rb
DEBUG -- ProcessFiles/CamelizeName - Items : 3 of 3 subitems passed
DEBUG -- ProcessFiles/CamelizeName - TestRun : 1 of 1 subitems passed
 INFO -- ProcessFiles - TestRun : Done
 INFO -- Run - TestRun : Done
STR
    sample_out = sample_out.lines.to_a

    run = job.execute
    output = logoutput.string.lines.to_a

    puts output

    expect(output.size).to eq sample_out.size
    output.each_with_index do |o, i|
      expect(o[/(?<=\] ).*/].strip).to eq sample_out[i].strip
    end

    expect(run.status_log.size).to eq 5
    expect(run.items.first.status_log.size).to eq 3

    [
        {task: 'Run', status: :DONE, progress: 2, max: 2},
        {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
        {task: 'ProcessFiles', status: :DONE, progress: 2, max: 2},
        {task: 'ProcessFiles/ChecksumTester', status: :DONE, progress: 1, max: 1},
        {task: 'ProcessFiles/CamelizeName', status: :DONE, progress: 1, max: 1},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(run.status_log[i][key]).to eq h[key] }
    end

    [
        {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
        {task: 'ProcessFiles/ChecksumTester', status: :DONE, progress: 3, max: 3},
        {task: 'ProcessFiles/CamelizeName', status: :DONE, progress: 3, max: 3},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(run.items.first.status_log[i][key]).to eq h[key] }
    end

    [
        {task: 'CollectFiles', status: :DONE, progress: nil, max: nil},
        {task: 'ProcessFiles/ChecksumTester', status: :DONE, progress: nil, max: nil},
        {task: 'ProcessFiles/CamelizeName', status: :DONE, progress: nil, max: nil},
    ].each_with_index do |h, i|
      h.keys.each { |key| expect(run.items.first.first.status_log[i][key]).to eq h[key] }
    end

  end

end