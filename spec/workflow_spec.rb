# frozen_string_literal: true

require_relative 'spec_helper'

require 'stringio'
require 'awesome_print'

basedir = File.absolute_path File.join(__dir__)
dirname = File.join(basedir, 'items')
datadir = File.join(basedir, 'data')

def check_output(logoutput, sample_out)
  sample_out = sample_out.lines.to_a.map(&:strip)
  output = logoutput.string.lines.to_a.map { |x| x[/(?<=\] ).*/].strip }

  puts 'output:'
  ap output

  expect(output.size).to eq sample_out.size
  output.each_with_index do |o, i|
    expect(o).to eq sample_out[i]
  end
end

def check_status_log(status_log, sample_status_log)
  # puts 'status_log:'
  status_log = status_log.map(&:pretty)
  # ap status_log
  expect(status_log.size).to eq sample_status_log.size
  sample_status_log.each_with_index do |h, i|
    h.keys.each do |key|
      puts "key: #{key} : #{status_log[i][key]} <=> #{h[key]}"
      expect(status_log[i][key]).to eq h[key]
    end
  end
end

context 'TestWorkflow' do
  before :each do
    # noinspection RubyResolve
    ::Libis::Workflow.configure do |cfg|
      cfg.itemdir = dirname
      cfg.taskdir = File.join(basedir, 'tasks')
      cfg.workdir = File.join(basedir, 'work')
      cfg.status_log = TestStatusLog
      cfg.logger.appenders =
        ::Logging::Appenders.string_io('StringIO', layout: ::Libis::Tools::Config.get_log_formatter)
      Libis::Workflow::Config.require_all cfg.itemdir
      Libis::Workflow::Config.require_all cfg.taskdir
      Libis::Workflow::Config.require_all cfg.workdir
    end
  end

  let(:logoutput) { ::Libis::Workflow::Config.logger.appenders.first.sio }

  let(:workflow) do
    TestWorkflow.new(
      tasks: [
        {
          class: 'CollectFiles',
          parameters: {
            recursive: true,
            location: 'data'
          }
        },
        {
          name: 'ProcessFiles',
          parameters: { recursive: false },
          tasks: [
            {
              class: 'ChecksumTester',
              parameters: {
                recursive: true,
                checksum_type: 'SHA1'
              }
            },
            {
              class: 'CamelizeName',
              parameters: { recursive: true }
            }
          ]
        }
      ]
    )
  end

  let(:job) do
    job = TestJob.new('TestJob', workflow)
    job.configure(location: datadir, checksum_type: 'SHA256')
    job
  end

  it 'should contain three tasks' do
    expect(workflow.config[:tasks].size).to eq 2
    expect(workflow.config[:tasks].first[:class]).to eq 'CollectFiles'
    expect(workflow.config[:tasks].last[:name]).to eq 'ProcessFiles'
  end

  # noinspection RubyResolve
  it 'should camelize the workitem name' do
    run = job.execute
    # ap logoutput.string.lines
    expect(run.options[0][:parameters][:location]).to eq datadir
    expect(job.items.size).to eq 1
    expect(job.items.first.class).to eq TestDirItem
    expect(job.items.first.size).to eq 3
    expect(job.items.first.items.size).to eq 3
    expect(job.items.first.items.first.class).to eq TestFileItem

    expect(job.items.first.name).to eq 'Abc'

    job.items.first.items.each_with_index do |x, i|
      expect(x.name).to eq %w[MyFile1.txt MyFile2.txt MyFile3.txt][i]
    end
  end

  it 'should return expected debug output' do
    run = job.execute

    check_output logoutput, <<~STR
       INFO - TestJob : Ingest run started.
       INFO - TestJob : Running subtask (1/2): CollectFiles
      DEBUG -- CollectFiles - TestJob : Processing subitem (1/1): abc
      DEBUG -- CollectFiles - abc : Processing subitem (1/3): my_file_1.txt
      DEBUG -- CollectFiles - abc : Processing subitem (2/3): my_file_2.txt
      DEBUG -- CollectFiles - abc : Processing subitem (3/3): my_file_3.txt
      DEBUG -- CollectFiles - abc : 3 of 3 subitems passed
      DEBUG -- CollectFiles - TestJob : 1 of 1 subitems passed
       INFO - TestJob : Running subtask (2/2): ProcessFiles
       INFO -- ProcessFiles - TestJob : Running subtask (1/2): ChecksumTester
      DEBUG -- ProcessFiles/ChecksumTester - TestJob : Processing subitem (1/1): abc
      DEBUG -- ProcessFiles/ChecksumTester - abc : Processing subitem (1/3): my_file_1.txt
      DEBUG -- ProcessFiles/ChecksumTester - abc : Processing subitem (2/3): my_file_2.txt
      DEBUG -- ProcessFiles/ChecksumTester - abc : Processing subitem (3/3): my_file_3.txt
      DEBUG -- ProcessFiles/ChecksumTester - abc : 3 of 3 subitems passed
      DEBUG -- ProcessFiles/ChecksumTester - TestJob : 1 of 1 subitems passed
       INFO -- ProcessFiles - TestJob : Running subtask (2/2): CamelizeName
      DEBUG -- ProcessFiles/CamelizeName - TestJob : Processing subitem (1/1): abc
      DEBUG -- ProcessFiles/CamelizeName - Abc : Processing subitem (1/3): my_file_1.txt
      DEBUG -- ProcessFiles/CamelizeName - Abc : Processing subitem (2/3): my_file_2.txt
      DEBUG -- ProcessFiles/CamelizeName - Abc : Processing subitem (3/3): my_file_3.txt
      DEBUG -- ProcessFiles/CamelizeName - Abc : 3 of 3 subitems passed
      DEBUG -- ProcessFiles/CamelizeName - TestJob : 1 of 1 subitems passed
       INFO -- ProcessFiles - TestJob : Done
       INFO - TestJob : Done
    STR

    check_status_log run.status_log, [
      { task: '', status: :done, progress: 2, max: 2 },
      { task: 'CollectFiles', status: :done, progress: 1, max: 1 },
      { task: 'ProcessFiles', status: :done, progress: 2, max: 2 },
      { task: 'ProcessFiles/ChecksumTester', status: :done, progress: 1, max: 1 },
      { task: 'ProcessFiles/CamelizeName', status: :done, progress: 1, max: 1 }
    ]

    check_status_log job.items.first.status_log, [
      { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
      { task: 'ProcessFiles/ChecksumTester', status: :done, progress: 3, max: 3 },
      { task: 'ProcessFiles/CamelizeName', status: :done, progress: 3, max: 3 }
    ]

    check_status_log job.items.first.items.first.status_log, [
      { task: 'CollectFiles', status: :done, progress: 0, max: nil },
      { task: 'ProcessFiles/ChecksumTester', status: :done, progress: 0, max: nil },
      { task: 'ProcessFiles/CamelizeName', status: :done, progress: 0, max: nil }
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

  let(:logoutput) { ::Libis::Workflow::Config.logger.appenders.first.sio }

  let(:workflow) do
    TestWorkflow.new(
      tasks: [
        {
          class: 'CollectFiles',
          parameters: {
            recursive: true,
            location: '.'
          }
        },
        {
          class: 'ProcessingTask',
          parameters: {
            recursive: true,
            config: 'success'
          }
        },
        {
          class: 'FinalTask',
          parameters: {
            recursive: true,
            run_always: false
          }
        }
      ]
    )
  end

  let(:processing) { 'success' }
  let(:force_run) { false }

  let(:job) do
    job = TestJob.new('TestJob', workflow)
    job.configure(location: dirname, processing: processing, run_always: force_run)
    job
  end

  let(:run) { job.execute }

  context 'without forcing final task' do
    let(:force_run) { false }

    context 'when processing successfully' do
      let(:processing) { 'success' }

      it 'should run final task' do
        run

        check_output logoutput, <<STR
 INFO -- TestJob : Ingest run started.
 INFO -- TestJob : Running subtask (1/3): CollectFiles
 INFO -- TestJob : Running subtask (2/3): ProcessingTask
 INFO -- ProcessingTask - TestJob : Task success
 INFO -- ProcessingTask - TestJob : Task success
 INFO -- ProcessingTask - TestJob : Task success
 INFO -- TestJob : Running subtask (3/3): FinalTask
 INFO -- FinalTask - TestJob : Final processing of test_dir_item.rb
 INFO -- FinalTask - TestJob : Final processing of test_file_item.rb
 INFO -- TestJob : Done
STR

        check_status_log run.status_log, [
          { task: 'TestRun', status: :DONE, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :DONE, progress: 1, max: 1 },
          { task: 'FinalTask', status: :DONE, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :DONE, progress: 3, max: 3 },
          { task: 'FinalTask', status: :DONE, progress: 3, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :DONE },
          { task: 'FinalTask', status: :DONE }
        ]
      end
    end

    context 'when stopped with async_halt' do
      let(:processing) { 'async_halt' }

      it 'should not run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- TestJob : Ingest run started.
           INFO -- TestJob : Running subtask (1/3): CollectFiles
           INFO -- TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - TestJob : Task failed with async_halt status
          ERROR -- ProcessingTask - TestJob : Task failed with async_halt status
          ERROR -- ProcessingTask - TestJob : Task failed with async_halt status
           WARN -- ProcessingTask - items : 3 subitem(s) halted in async process
           WARN -- ProcessingTask - TestJob : 1 subitem(s) halted in async process
           WARN -- TestJob : 1 subtask(s) halted in async process
           INFO -- TestJob : Waiting for halted async process
        STR

        check_status_log run.status_log, [
          { task: 'TestRun', status: :ASYNC_HALT, progress: 2, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :ASYNC_HALT, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :ASYNC_HALT, progress: 3, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :ASYNC_HALT }
        ]
      end
    end

    context 'when stopped with fail' do
      let(:processing) { 'fail' }

      it 'should not run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- TestJob : Ingest run started.
           INFO -- TestJob : Running subtask (1/3): CollectFiles
           INFO -- TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - TestJob : Task failed with failed status
          ERROR -- ProcessingTask - TestJob : Task failed with failed status
          ERROR -- ProcessingTask - TestJob : Task failed with failed status
          ERROR -- ProcessingTask - items : 3 subitem(s) failed
          ERROR -- ProcessingTask - TestJob : 1 subitem(s) failed
          ERROR -- TestJob : 1 subtask(s) failed
           INFO -- TestJob : Failed
        STR

        check_status_log run.status_log, [
          { task: 'TestRun', status: :FAILED, progress: 2, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :FAILED, progress: 3, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :FAILED }
        ]
      end
    end

    context 'when stopped with error' do
      let(:processing) { 'error' }

      it 'should not run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- TestJob : Ingest run started.
           INFO -- TestJob : Running subtask (1/3): CollectFiles
           INFO -- TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - items/test_dir_item.rb : Error processing subitem (1/2): Task failed with WorkflowError exception
          ERROR -- ProcessingTask - items/test_file_item.rb : Error processing subitem (2/2): Task failed with WorkflowError exception
          ERROR -- ProcessingTask - items : 2 subitem(s) failed
          ERROR -- ProcessingTask - TestJob : 1 subitem(s) failed
          ERROR -- TestJob : 1 subtask(s) failed
           INFO -- TestJob : Failed
        STR

        check_status_log run.status_log, [
          { task: 'TestRun', status: :FAILED, progress: 2, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :FAILED, progress: 0, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :FAILED }
        ]
      end
    end

    context 'when stopped with abort' do
      let(:processing) { 'abort' }

      it 'should not run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- TestJob : Ingest run started.
           INFO -- TestJob : Running subtask (1/3): CollectFiles
           INFO -- TestJob : Running subtask (2/3): ProcessingTask
          FATAL -- ProcessingTask - items/test_dir_item.rb : Fatal error processing subitem (1/3): Task failed with WorkflowAbort exception
          ERROR -- ProcessingTask - items : 1 subitem(s) failed
          ERROR -- ProcessingTask - TestJob : 1 subitem(s) failed
          ERROR -- TestJob : 1 subtask(s) failed
           INFO -- TestJob : Failed
        STR

        check_status_log run.status_log, [
          { task: 'TestRun', status: :FAILED, progress: 2, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :FAILED, progress: 0, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :FAILED }
        ]
      end
    end
  end

  context 'with forcing final task' do
    let(:force_run) { true }

    context 'when processing successfully' do
      let(:processing) { 'success' }

      it 'should run final task' do
        run

        check_output logoutput, <<STR
 INFO -- TestJob : Ingest run started.
 INFO -- TestJob : Running subtask (1/3): CollectFiles
 INFO -- TestJob : Running subtask (2/3): ProcessingTask
 INFO -- ProcessingTask - TestJob : Task success
 INFO -- ProcessingTask - TestJob : Task success
 INFO -- ProcessingTask - TestJob : Task success
 INFO -- TestJob : Running subtask (3/3): FinalTask
 INFO -- FinalTask - TestJob : Final processing of test_dir_item.rb
 INFO -- FinalTask - TestJob : Final processing of test_file_item.rb
 INFO -- TestJob : Done
STR

        check_status_log run.status_log, [
          { task: 'TestRun', status: :DONE, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :DONE, progress: 1, max: 1 },
          { task: 'FinalTask', status: :DONE, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :DONE, progress: 3, max: 3 },
          { task: 'FinalTask', status: :DONE, progress: 3, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :DONE },
          { task: 'FinalTask', status: :DONE }
        ]
      end
    end

    context 'when stopped with async_halt' do
      let(:processing) { 'async_halt' }

      it 'should run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- TestJob : Ingest run started.
           INFO -- TestJob : Running subtask (1/3): CollectFiles
           INFO -- TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - TestJob : Task failed with async_halt status
          ERROR -- ProcessingTask - TestJob : Task failed with async_halt status
           WARN -- ProcessingTask - items : 2 subitem(s) halted in async process
           WARN -- ProcessingTask - TestJob : 1 subitem(s) halted in async process
           INFO -- TestJob : Running subtask (3/3): FinalTask
           INFO -- FinalTask - TestJob : Final processing of test_dir_item.rb
           INFO -- FinalTask - TestJob : Final processing of test_file_item.rb
           WARN -- TestJob : 1 subtask(s) halted in async process
           INFO -- TestJob : Waiting for halted async process
        STR

        check_status_log run.status_log, [
          { task: 'TestRun', status: :ASYNC_HALT, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :ASYNC_HALT, progress: 1, max: 1 },
          { task: 'FinalTask', status: :DONE, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :ASYNC_HALT, progress: 3, max: 3 },
          { task: 'FinalTask', status: :DONE, progress: 3, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :ASYNC_HALT },
          { task: 'FinalTask', status: :DONE }
        ]
      end
    end

    context 'when stopped with fail' do
      let(:processing) { 'fail' }

      it 'should run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- TestJob : Ingest run started.
           INFO -- TestJob : Running subtask (1/3): CollectFiles
           INFO -- TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - TestJob : Task failed with failed status
          ERROR -- ProcessingTask - TestJob : Task failed with failed status
          ERROR -- ProcessingTask - items : 2 subitem(s) failed
          ERROR -- ProcessingTask - TestRun : 1 subitem(s) failed
           INFO -- TestJob : Running subtask (3/3): FinalTask
           INFO -- FinalTask - TestJob : Final processing of test_dir_item.rb
           INFO -- FinalTask - TestJob : Final processing of test_file_item.rb
          ERROR -- TestJob : 1 subtask(s) failed
           INFO -- TestJob : Failed
        STR
        check_status_log run.status_log, [
          { task: 'TestRun', status: :FAILED, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1 },
          { task: 'FinalTask', status: :DONE, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :FAILED, progress: 3, max: 3 },
          { task: 'FinalTask', status: :DONE, progress: 3, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :FAILED },
          { task: 'FinalTask', status: :DONE }
        ]
      end

      it 'should run final task during retry' do
        run

        logoutput.truncate(0)
        run.execute :retry

        check_output logoutput, <<~STR
           INFO -- TestJob : Ingest run started.
           INFO -- TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - TestJob : Task failed with failed status
          ERROR -- ProcessingTask - TestJob : Task failed with failed status
          ERROR -- ProcessingTask - items : 2 subitem(s) failed
          ERROR -- ProcessingTask - TestJob : 1 subitem(s) failed
           INFO -- TestJob : Running subtask (3/3): FinalTask
           INFO -- FinalTask - TestJob : Final processing of test_dir_item.rb
           INFO -- FinalTask - TestJob : Final processing of test_file_item.rb
          ERROR -- TestJob : 1 subtask(s) failed
           INFO -- TestJob : Failed
        STR
        check_status_log run.status_log, [
          { task: 'TestRun', status: :FAILED, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1 },
          { task: 'FinalTask', status: :DONE, progress: 1, max: 1 },
          { task: 'TestRun', status: :FAILED, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1 },
          { task: 'FinalTask', status: :DONE, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :FAILED, progress: 3, max: 3 },
          { task: 'FinalTask', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :FAILED, progress: 3, max: 3 },
          { task: 'FinalTask', status: :DONE, progress: 3, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :FAILED },
          { task: 'FinalTask', status: :DONE },
          { task: 'ProcessingTask', status: :FAILED },
          { task: 'FinalTask', status: :DONE }
        ]
      end
    end

    context 'when stopped with error' do
      let(:processing) { 'error' }

      it 'should run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- TestJob : Ingest run started.
           INFO -- TestJob : Running subtask (1/3): CollectFiles
           INFO -- TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - items/test_dir_item.rb : Error processing subitem (1/2): Task failed with WorkflowError exception
          ERROR -- ProcessingTask - items/test_file_item.rb : Error processing subitem (2/2): Task failed with WorkflowError exception
          ERROR -- ProcessingTask - items : 2 subitem(s) failed
          ERROR -- ProcessingTask - TestJob : 1 subitem(s) failed
           INFO -- TestJob : Running subtask (3/3): FinalTask
           INFO -- FinalTask - TestJob : Final processing of test_dir_item.rb
           INFO -- FinalTask - TestJob : Final processing of test_file_item.rb
          ERROR -- TestJob : 1 subtask(s) failed
           INFO -- TestJob : Failed
        STR
        check_status_log run.status_log, [
          { task: 'TestRun', status: :FAILED, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1 },
          { task: 'FinalTask', status: :DONE, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :FAILED, progress: 0, max: 3 },
          { task: 'FinalTask', status: :DONE, progress: 3, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :FAILED },
          { task: 'FinalTask', status: :DONE }
        ]
      end
    end

    context 'when stopped with abort' do
      let(:processing) { 'abort' }

      it 'should run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- TestJob : Ingest run started.
           INFO -- TestJob : Running subtask (1/3): CollectFiles
           INFO -- TestJob : Running subtask (2/3): ProcessingTask
          FATAL -- ProcessingTask - items/test_dir_item.rb : Fatal error processing subitem (1/3): Task failed with WorkflowAbort exception
          ERROR -- ProcessingTask - items : 1 subitem(s) failed
          ERROR -- ProcessingTask - TestJob : 1 subitem(s) failed
           INFO -- TestJob : Running subtask (3/3): FinalTask
           INFO -- FinalTask - TestJob : Final processing of test_dir_item.rb
           INFO -- FinalTask - TestJob : Final processing of test_file_item.rb
          ERROR -- TestJob : 1 subtask(s) failed
           INFO -- TestJob : Failed
        STR

        check_status_log run.status_log, [
          { task: 'TestRun', status: :FAILED, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :DONE, progress: 1, max: 1 },
          { task: 'ProcessingTask', status: :FAILED, progress: 1, max: 1 },
          { task: 'FinalTask', status: :DONE, progress: 1, max: 1 }
        ]

        check_status_log run.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :FAILED, progress: 0, max: 3 },
          { task: 'FinalTask', status: :DONE, progress: 3, max: 3 }
        ]

        check_status_log run.items.first.items.first.status_log, [
          { task: 'CollectFiles', status: :DONE },
          { task: 'ProcessingTask', status: :FAILED },
          { task: 'FinalTask', status: :DONE }
        ]
      end
    end
  end
end
