require_relative 'spec_helper'

require 'stringio'
require 'awesome_print'

basedir = File.absolute_path File.join(File.dirname(__FILE__))
dirname = File.join(basedir, 'items')

def check_output(logoutput, sample_out)
  sample_out = sample_out.lines.to_a.map {|x| x.strip}
  output = logoutput.string.lines.to_a.map {|x| x[/(?<=\] ).*/].strip}

  puts 'output:'
  ap output

  expect(output.size).to eq sample_out.size
  output.each_with_index do |o, i|
    expect(o).to eq sample_out[i]
  end
end

def check_status_log(status_log, sample_status_log)
  puts 'status_log:'
  status_log.each { |e| ap e }
  expect(status_log.size).to eq sample_status_log.size
  sample_status_log.each_with_index do |h, i|
    h.keys.each {|key| expect(status_log[i][key.to_s]).to eq h[key]}
  end
end

context 'TestWorkflow' do

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

  let(:logoutput) {::Libis::Workflow::Config.logger.appenders.first.sio}

  let(:workflow) {
    workflow = ::Libis::Workflow::Workflow.new
    workflow.configure(
        name: 'TestWorkflow',
        description: 'Workflow for testing',
        tasks: [
            {class: 'CollectFiles', recursive: true},
            {
                name: 'ProcessFiles', recursive: false,
                tasks: [
                    {class: 'ChecksumTester', recursive: true},
                    {class: 'CamelizeName', :recursive => true}
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
    run = job.execute

    check_output logoutput, <<STR
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

    check_status_log run.status_log, [
        {task: 'Run', status: :DONE, progress: 2, max: 2},
        {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
        {task: 'ProcessFiles', status: :DONE, progress: 2, max: 2},
        {task: 'ProcessFiles/ChecksumTester', status: :DONE, progress: 1, max: 1},
        {task: 'ProcessFiles/CamelizeName', status: :DONE, progress: 1, max: 1},
    ]

    check_status_log run.items.first.status_log, [
        {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
        {task: 'ProcessFiles/ChecksumTester', status: :DONE, progress: 3, max: 3},
        {task: 'ProcessFiles/CamelizeName', status: :DONE, progress: 3, max: 3},
    ]

    check_status_log run.items.first.items.first.status_log, [
        {task: 'CollectFiles', status: :DONE, progress: nil, max: nil},
        {task: 'ProcessFiles/ChecksumTester', status: :DONE, progress: nil, max: nil},
        {task: 'ProcessFiles/CamelizeName', status: :DONE, progress: nil, max: nil},
    ]

  end

end

context 'Test run_always' do

  before :each do

    # noinspection RubyResolve
    ::Libis::Workflow.configure do |cfg|
      cfg.itemdir = dirname
      cfg.taskdir = File.join(basedir, 'tasks')
      cfg.workdir = File.join(basedir, 'work')
      cfg.logger.appenders =
          ::Logging::Appenders.string_io('StringIO', layout: ::Libis::Tools::Config.get_log_formatter)
      cfg.logger.level = :INFO
    end
  end

  let(:logoutput) {::Libis::Workflow::Config.logger.appenders.first.sio}

  let(:workflow) {
    workflow = ::Libis::Workflow::Workflow.new
    workflow.configure(
        name: 'TestRunAlways',
        description: 'Workflow for testing run_always options',
        tasks: [
            {class: 'CollectFiles', recursive: true},
            {class: 'ProcessingTask', recursive: true},
            {class: 'FinalTask', recursive: true}
        ],
        input: {
            dirname: {default: '.', propagate_to: 'CollectFiles#location'},
            processing: {default: 'success', propagate_to: 'ProcessingTask#config'},
            force_run: {default: false, propagate_to: 'FinalTask#run_always'}
        }
    )
    workflow
  }

  let(:processing) {'success'}
  let(:force_run) {false}

  let(:job) {
    job = ::Libis::Workflow::Job.new
    job.configure(
        name: 'TestJob',
        description: 'Job for testing run_always',
        workflow: workflow,
        run_object: 'TestRun',
        input: {dirname: dirname, processing: processing, force_run: force_run},
        )
    job
  }

  let(:run) {job.execute}

  context 'without forcing final task' do
    let(:force_run) {false}

    context 'when processing successfully' do
      let(:processing) {'success'}

      it 'should run final task' do
        run

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
 INFO -- ProcessingTask - TestRun : Task success
 INFO -- ProcessingTask - TestRun : Task success
 INFO -- ProcessingTask - TestRun : Task success
 INFO -- Run - TestRun : Running subtask (3/3): FinalTask
 INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_run.rb
 INFO -- Run - TestRun : Done
STR

        check_status_log run.status_log, [
            {task: 'Run', status: :DONE, progress: 3, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :DONE, progress: 1, max: 1},
            {task: 'FinalTask', status: :DONE, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :DONE, progress: 3, max: 3},
            {task: 'FinalTask', status: :DONE, progress: 3, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :DONE},
            {task: 'FinalTask', status: :DONE},
        ]

      end

    end

    context 'when stopped with async_halt' do
      let(:processing) {'async_halt'}

      it 'should not run final task' do
        run

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
 WARN -- ProcessingTask - items : 3 subitem(s) halted in async process
 WARN -- ProcessingTask - TestRun : 1 subitem(s) halted in async process
 WARN -- Run - TestRun : 1 subtask(s) halted in async process
 INFO -- Run - TestRun : Waiting for halted async process
STR

        check_status_log run.status_log ,[
            {task: 'Run', status: :ASYNC_HALT, progress: 2, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :ASYNC_HALT, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :ASYNC_HALT, progress: 3, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :ASYNC_HALT},
        ]

      end

    end

    context 'when stopped with fail' do
      let(:processing) {'fail'}

      it 'should not run final task' do
        run

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
ERROR -- ProcessingTask - TestRun : Task failed with failed status
ERROR -- ProcessingTask - TestRun : Task failed with failed status
ERROR -- ProcessingTask - TestRun : Task failed with failed status
ERROR -- ProcessingTask - items : 3 subitem(s) failed
ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
ERROR -- Run - TestRun : 1 subtask(s) failed
 INFO -- Run - TestRun : Failed
STR

        check_status_log run.status_log, [
            {task: 'Run', status: :FAILED, progress: 2, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :FAILED, progress: 3, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :FAILED},
        ]

      end

    end

    context 'when stopped with error' do
      let(:processing) {'error'}

      it 'should not run final task' do
        run

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
ERROR -- ProcessingTask - items/test_dir_item.rb : Error processing subitem (1/3): Task failed with WorkflowError exception
ERROR -- ProcessingTask - items/test_file_item.rb : Error processing subitem (2/3): Task failed with WorkflowError exception
ERROR -- ProcessingTask - items/test_run.rb : Error processing subitem (3/3): Task failed with WorkflowError exception
ERROR -- ProcessingTask - items : 3 subitem(s) failed
ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
ERROR -- Run - TestRun : 1 subtask(s) failed
 INFO -- Run - TestRun : Failed
STR

        check_status_log run.status_log, [
            {task: 'Run', status: :FAILED, progress: 2, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :FAILED, progress: 0, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :FAILED},
        ]

      end

    end

    context 'when stopped with abort' do
      let(:processing) {'abort'}

      it 'should not run final task' do
        run

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
FATAL -- ProcessingTask - items/test_dir_item.rb : Fatal error processing subitem (1/3): Task failed with WorkflowAbort exception
ERROR -- ProcessingTask - items : 1 subitem(s) failed
ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
ERROR -- Run - TestRun : 1 subtask(s) failed
 INFO -- Run - TestRun : Failed
STR

        check_status_log run.status_log, [
            {task: 'Run', status: :FAILED, progress: 2, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :FAILED, progress: 0, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :FAILED},
        ]

      end

    end

  end

  context 'with forcing final task' do
    let(:force_run) {true}

    context 'when processing successfully' do
      let(:processing) {'success'}

      it 'should run final task' do
        run

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
 INFO -- ProcessingTask - TestRun : Task success
 INFO -- ProcessingTask - TestRun : Task success
 INFO -- ProcessingTask - TestRun : Task success
 INFO -- Run - TestRun : Running subtask (3/3): FinalTask
 INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_run.rb
 INFO -- Run - TestRun : Done
STR

        check_status_log run.status_log, [
            {task: 'Run', status: :DONE, progress: 3, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :DONE, progress: 1, max: 1},
            {task: 'FinalTask', status: :DONE, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :DONE, progress: 3, max: 3},
            {task: 'FinalTask', status: :DONE, progress: 3, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :DONE},
            {task: 'FinalTask', status: :DONE},
        ]

      end

    end

    context 'when stopped with async_halt' do
      let(:processing) {'async_halt'}

      it 'should run final task' do
        run

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
ERROR -- ProcessingTask - TestRun : Task failed with async_halt status
 WARN -- ProcessingTask - items : 3 subitem(s) halted in async process
 WARN -- ProcessingTask - TestRun : 1 subitem(s) halted in async process
 INFO -- Run - TestRun : Running subtask (3/3): FinalTask
 INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_run.rb
 WARN -- Run - TestRun : 1 subtask(s) halted in async process
 INFO -- Run - TestRun : Waiting for halted async process
STR

        check_status_log run.status_log, [
            {task: 'Run', status: :ASYNC_HALT, progress: 3, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :ASYNC_HALT, progress: 1, max: 1},
            {task: 'FinalTask', status: :DONE, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :ASYNC_HALT, progress: 3, max: 3},
            {task: 'FinalTask', status: :DONE, progress: 3, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :ASYNC_HALT},
            {task: 'FinalTask', status: :DONE},
        ]

      end

    end

    context 'when stopped with fail' do
      let(:processing) {'fail'}

      it 'should run final task' do
        run

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
ERROR -- ProcessingTask - TestRun : Task failed with failed status
ERROR -- ProcessingTask - TestRun : Task failed with failed status
ERROR -- ProcessingTask - TestRun : Task failed with failed status
ERROR -- ProcessingTask - items : 3 subitem(s) failed
ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
 INFO -- Run - TestRun : Running subtask (3/3): FinalTask
 INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_run.rb
ERROR -- Run - TestRun : 1 subtask(s) failed
 INFO -- Run - TestRun : Failed
STR
        check_status_log run.status_log, [
            {task: 'Run', status: :FAILED, progress: 3, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1},
            {task: 'FinalTask', status: :DONE, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :FAILED, progress: 3, max: 3},
            {task: 'FinalTask', status: :DONE, progress: 3, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :FAILED},
            {task: 'FinalTask', status: :DONE},
        ]

      end

      it 'should run final task during retry' do
        run

        logoutput.truncate(0)
        run.run :retry

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
ERROR -- ProcessingTask - TestRun : Task failed with failed status
ERROR -- ProcessingTask - TestRun : Task failed with failed status
ERROR -- ProcessingTask - TestRun : Task failed with failed status
ERROR -- ProcessingTask - items : 3 subitem(s) failed
ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
 INFO -- Run - TestRun : Running subtask (3/3): FinalTask
 INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_run.rb
ERROR -- Run - TestRun : 1 subtask(s) failed
 INFO -- Run - TestRun : Failed
STR
        check_status_log run.status_log, [
            {task: 'Run', status: :FAILED, progress: 3, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1},
            {task: 'FinalTask', status: :DONE, progress: 1, max: 1},
            {task: 'Run', status: :FAILED, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1},
            {task: 'FinalTask', status: :DONE, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :FAILED, progress: 3, max: 3},
            {task: 'FinalTask', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :FAILED, progress: 3, max: 3},
            {task: 'FinalTask', status: :DONE, progress: 3, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :FAILED},
            {task: 'FinalTask', status: :DONE},
            {task: 'ProcessingTask', status: :FAILED},
            {task: 'FinalTask', status: :DONE},
        ]

      end

    end

    context 'when stopped with error' do
      let(:processing) {'error'}

      it 'should run final task' do
        run

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
ERROR -- ProcessingTask - items/test_dir_item.rb : Error processing subitem (1/3): Task failed with WorkflowError exception
ERROR -- ProcessingTask - items/test_file_item.rb : Error processing subitem (2/3): Task failed with WorkflowError exception
ERROR -- ProcessingTask - items/test_run.rb : Error processing subitem (3/3): Task failed with WorkflowError exception
ERROR -- ProcessingTask - items : 3 subitem(s) failed
ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
 INFO -- Run - TestRun : Running subtask (3/3): FinalTask
 INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_run.rb
ERROR -- Run - TestRun : 1 subtask(s) failed
 INFO -- Run - TestRun : Failed
STR
        check_status_log run.status_log, [
            {task: 'Run', status: :FAILED, progress: 3, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1},
            {task: 'FinalTask', status: :DONE, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :FAILED, progress: 0, max: 3},
            {task: 'FinalTask', status: :DONE, progress: 3, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :FAILED},
            {task: 'FinalTask', status: :DONE},
        ]

      end

    end

    context 'when stopped with abort' do
      let(:processing) {'abort'}

      it 'should run final task' do
        run

        check_output logoutput, <<STR
 INFO -- Run - TestRun : Ingest run started.
 INFO -- Run - TestRun : Running subtask (1/3): CollectFiles
 INFO -- Run - TestRun : Running subtask (2/3): ProcessingTask
FATAL -- ProcessingTask - items/test_dir_item.rb : Fatal error processing subitem (1/3): Task failed with WorkflowAbort exception
ERROR -- ProcessingTask - items : 1 subitem(s) failed
ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
 INFO -- Run - TestRun : Running subtask (3/3): FinalTask
 INFO -- FinalTask - TestRun : Final processing of test_dir_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_file_item.rb
 INFO -- FinalTask - TestRun : Final processing of test_run.rb
ERROR -- Run - TestRun : 1 subtask(s) failed
 INFO -- Run - TestRun : Failed
STR

        check_status_log run.status_log, [
            {task: 'Run', status: :FAILED, progress: 3, max: 3},
            {task: 'CollectFiles', status: :DONE, progress: 1, max: 1},
            {task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1},
            {task: 'FinalTask', status: :DONE, progress: 1, max: 1},
        ]

        check_status_log run.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE, progress: 3, max: 3},
            {task: 'ProcessingTask', status: :FAILED, progress: 0, max: 3},
            {task: 'FinalTask', status: :DONE, progress: 3, max: 3},
        ]

        check_status_log run.items.first.items.first.status_log, [
            {task: 'CollectFiles', status: :DONE},
            {task: 'ProcessingTask', status: :FAILED},
            {task: 'FinalTask', status: :DONE},
        ]

      end

    end

  end

end