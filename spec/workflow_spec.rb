# frozen_string_literal: true

require_relative 'spec_helper'

require 'stringio'
require 'awesome_print'


def check_output(logoutput, sample_out)
  sample_out = sample_out.lines.to_a.map(&:strip)
  output = logoutput.string.lines.to_a.map { |x| x[/(?<=\] ).*/].strip }

  # puts 'output:'
  # ap output

  expect(output.size).to eq sample_out.size
  output.each_with_index do |o, i|
    expect(o).to eq sample_out[i]
  end
end

def check_status_log(status_log, sample_status_log)
  status_log = status_log.map(&:pretty)
  # puts 'status_log:'
  # ap status_log
  expect(status_log.size).to eq sample_status_log.size
  sample_status_log.each_with_index do |h, i|
    h.keys.each do |key|
      expect(status_log[i][key]).to eq h[key]
    end
  end
end

context 'TestWorkflow' do
  before :each do
  end

  let(:logoutput) { ::Libis::Workflow::Config.logger.appenders.first.sio }
  let(:debug_level) { :DEBUG }

  let(:workflow) do
    TestWorkflow.new(
      tasks: [
        {
          class: 'CollectFiles',
          parameters: {
            location: 'data'
          }
        },
        {
          name: 'ProcessFiles',
          tasks: [
            {
              class: 'ChecksumTester',
              parameters: {
                checksum_type: 'SHA1'
              }
            },
            {
              class: 'CamelizeName'
            }
          ]
        }
      ]
    )
  end

  let(:job) do
    job = TestJob.new('TestJob', workflow)
    job.configure(location: @datadir, checksum_type: 'SHA256')
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

    expect(run.config[:tasks][0][:parameters][:location]).to eq @datadir
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
       INFO -- Run-1 - TestJob : Ingest run started.
       INFO -- Run-1 - TestJob : Running subtask (1/2): CollectFiles
      DEBUG -- CollectFiles - TestJob : Processing subitem (1/1): abc
      DEBUG -- CollectFiles - abc : Processing subitem (1/3): my_file_1.txt
      DEBUG -- CollectFiles - abc : Processing subitem (2/3): my_file_2.txt
      DEBUG -- CollectFiles - abc : Processing subitem (3/3): my_file_3.txt
      DEBUG -- CollectFiles - abc : 3 of 3 subitems passed
      DEBUG -- CollectFiles - TestJob : 1 of 1 subitems passed
       INFO -- Run-1 - TestJob : Running subtask (2/2): ProcessFiles
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
       INFO -- Run-1 - TestJob : Done
    STR

    check_status_log run.status_log, [
      { task: 'Run-1', status: :done, progress: 2, max: 2 },
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

  let(:logoutput) { ::Libis::Workflow::Config.logger.appenders.first.sio }
  let(:debug_level) { :INFO }

  let(:workflow) do
    TestWorkflow.new(
      tasks: [
        {
          class: 'CollectFiles',
          parameters: {
            location: '.'
          }
        },
        {
          class: 'ProcessingTask',
          parameters: {
            config: 'success'
          }
        },
        {
          class: 'FinalTask',
          parameters: {
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
    job.configure(location: @dirname, config: processing, run_always: force_run)
    job
  end

  let(:run) { job.execute }

  context 'without forcing final task' do
    let(:force_run) { false }

    context 'when processing successfully' do
      let(:processing) { 'success' }

      it 'should run final task' do
        run

        check_output logoutput, <<~STR
          INFO -- Run-1 - TestJob : Ingest run started.
          INFO -- Run-1 - TestJob : Running subtask (1/3): CollectFiles
          INFO -- Run-1 - TestJob : Running subtask (2/3): ProcessingTask
          INFO -- ProcessingTask - test_dir_item.rb : Task success
          INFO -- ProcessingTask - test_file_item.rb : Task success
          INFO -- ProcessingTask - test_work_item.rb : Task success
          INFO -- Run-1 - TestJob : Running subtask (3/3): FinalTask
          INFO -- FinalTask : Final processing of test_dir_item.rb
          INFO -- FinalTask : Final processing of test_file_item.rb
          INFO -- FinalTask : Final processing of test_work_item.rb
          INFO -- Run-1 - TestJob : Done
         STR

        check_status_log run.status_log, [
          { task: 'Run-1', status: :done, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :done, progress: 3, max: 3 },
          { task: 'FinalTask', status: :done, progress: 3, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :done },
          { task: 'FinalTask', status: :done }
        ]
      end
    end

    context 'when stopped with async_halt' do
      let(:processing) { 'async_halt' }

      it 'should not run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- Run-1 - TestJob : Ingest run started.
           INFO -- Run-1 - TestJob : Running subtask (1/3): CollectFiles
           INFO -- Run-1 - TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - test_dir_item.rb : Task failed with async_halt status
          ERROR -- ProcessingTask - test_file_item.rb : Task failed with async_halt status
          ERROR -- ProcessingTask - test_work_item.rb : Task failed with async_halt status
           WARN -- ProcessingTask - TestJob : 3 subitem(s) halted in async process
           WARN -- Run-1 - TestJob : 1 subtask(s) halted in async process
           INFO -- Run-1 - TestJob : Remote process failed
        STR

        check_status_log run.status_log, [
          { task: 'Run-1', status: :async_halt, progress: 2, max: 3 },
          { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :async_halt, progress: 3, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :async_halt }
        ]
      end
    end

    context 'when stopped with fail' do
      let(:processing) { 'fail' }

      it 'should not run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- Run-1 - TestJob : Ingest run started.
           INFO -- Run-1 - TestJob : Running subtask (1/3): CollectFiles
           INFO -- Run-1 - TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - test_dir_item.rb : Task failed with failed status
          ERROR -- ProcessingTask - test_file_item.rb : Task failed with failed status
          ERROR -- ProcessingTask - test_work_item.rb : Task failed with failed status
          ERROR -- ProcessingTask - TestJob : 3 subitem(s) failed
          ERROR -- Run-1 - TestJob : 1 subtask(s) failed
           INFO -- Run-1 - TestJob : Failed
        STR

        check_status_log run.status_log, [
          { task: 'Run-1', status: :failed, progress: 2, max: 3 },
          { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :failed, progress: 3, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :failed }
        ]
      end
    end

    context 'when stopped with error' do
      let(:processing) { 'error' }

      it 'should not run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- Run-1 - TestJob : Ingest run started.
           INFO -- Run-1 - TestJob : Running subtask (1/3): CollectFiles
           INFO -- Run-1 - TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - test_dir_item.rb : Task failed with WorkflowError exception
          ERROR -- ProcessingTask - TestJob : Error processing subitem (1/3): Task failed with WorkflowError exception
          ERROR -- ProcessingTask - test_file_item.rb : Task failed with WorkflowError exception
          ERROR -- ProcessingTask - TestJob : Error processing subitem (2/3): Task failed with WorkflowError exception
          ERROR -- ProcessingTask - test_work_item.rb : Task failed with WorkflowError exception
          ERROR -- ProcessingTask - TestJob : Error processing subitem (3/3): Task failed with WorkflowError exception
          ERROR -- ProcessingTask - TestJob : 3 subitem(s) failed
          ERROR -- Run-1 - TestJob : 1 subtask(s) failed
           INFO -- Run-1 - TestJob : Failed
        STR

        check_status_log run.status_log, [
          { task: 'Run-1', status: :failed, progress: 2, max: 3 },
          { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :failed, progress: 3, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :failed }
        ]
      end
    end

    context 'when stopped with abort' do
      let(:processing) { 'abort' }

      it 'should not run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- Run-1 - TestJob : Ingest run started.
           INFO -- Run-1 - TestJob : Running subtask (1/3): CollectFiles
           INFO -- Run-1 - TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - test_dir_item.rb : Task failed with WorkflowAbort exception
          FATAL -- ProcessingTask - TestJob : Fatal error processing subitem (1/3): Task failed with WorkflowAbort exception
          ERROR -- ProcessingTask - TestJob : 1 subitem(s) failed
          ERROR -- Run-1 - TestJob : 1 subtask(s) failed
           INFO -- Run-1 - TestJob : Failed
        STR

        check_status_log run.status_log, [
          { task: 'Run-1', status: :failed, progress: 2, max: 3 },
          { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :failed, progress: 1, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :failed }
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

        check_output logoutput, <<~STR
          INFO -- Run-1 - TestJob : Ingest run started.
          INFO -- Run-1 - TestJob : Running subtask (1/3): CollectFiles
          INFO -- Run-1 - TestJob : Running subtask (2/3): ProcessingTask
          INFO -- ProcessingTask - test_dir_item.rb : Task success
          INFO -- ProcessingTask - test_file_item.rb : Task success
          INFO -- ProcessingTask - test_work_item.rb : Task success
          INFO -- Run-1 - TestJob : Running subtask (3/3): FinalTask
          INFO -- FinalTask : Final processing of test_dir_item.rb
          INFO -- FinalTask : Final processing of test_file_item.rb
          INFO -- FinalTask : Final processing of test_work_item.rb
          INFO -- Run-1 - TestJob : Done
        STR

        check_status_log run.status_log, [
          { task: 'Run-1', status: :done, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :done, progress: 3, max: 3 },
          { task: 'FinalTask', status: :done, progress: 3, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :done },
          { task: 'FinalTask', status: :done }
        ]
      end
    end

    context 'when stopped with async_halt' do
      let(:processing) { 'async_halt' }

      it 'should run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- Run-1 - TestJob : Ingest run started.
           INFO -- Run-1 - TestJob : Running subtask (1/3): CollectFiles
           INFO -- Run-1 - TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - test_dir_item.rb : Task failed with async_halt status
          ERROR -- ProcessingTask - test_file_item.rb : Task failed with async_halt status
          ERROR -- ProcessingTask - test_work_item.rb : Task failed with async_halt status
           WARN -- ProcessingTask - TestJob : 3 subitem(s) halted in async process
           INFO -- Run-1 - TestJob : Running subtask (3/3): FinalTask
           INFO -- FinalTask : Final processing of test_dir_item.rb
           INFO -- FinalTask : Final processing of test_file_item.rb
           INFO -- FinalTask : Final processing of test_work_item.rb
           WARN -- Run-1 - TestJob : 1 subtask(s) halted in async process
           INFO -- Run-1 - TestJob : Remote process failed
        STR

        check_status_log run.status_log, [
          { task: 'Run-1', status: :async_halt, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :async_halt, progress: 3, max: 3 },
          { task: 'FinalTask', status: :done, progress: 3, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :async_halt },
          { task: 'FinalTask', status: :done }
        ]
      end
    end

    context 'when stopped with fail' do
      let(:processing) { 'fail' }

      it 'should run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- Run-1 - TestJob : Ingest run started.
           INFO -- Run-1 - TestJob : Running subtask (1/3): CollectFiles
           INFO -- Run-1 - TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - test_dir_item.rb : Task failed with failed status
          ERROR -- ProcessingTask - test_file_item.rb : Task failed with failed status
          ERROR -- ProcessingTask - test_work_item.rb : Task failed with failed status
          ERROR -- ProcessingTask - TestJob : 3 subitem(s) failed
           INFO -- Run-1 - TestJob : Running subtask (3/3): FinalTask
           INFO -- FinalTask : Final processing of test_dir_item.rb
           INFO -- FinalTask : Final processing of test_file_item.rb
           INFO -- FinalTask : Final processing of test_work_item.rb
          ERROR -- Run-1 - TestJob : 1 subtask(s) failed
           INFO -- Run-1 - TestJob : Failed
        STR
        check_status_log run.status_log, [
          { task: 'Run-1', status: :failed, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :failed, progress: 3, max: 3 },
          { task: 'FinalTask', status: :done, progress: 3, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :failed },
          { task: 'FinalTask', status: :done }
        ]
      end

      it 'should run final task during retry' do
        run

        logoutput.truncate(0)
        run = job.execute action: 'retry'

        check_output logoutput, <<~STR
           INFO -- Run-2 - TestJob : Ingest run started.
           INFO -- Run-2 - TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - test_dir_item.rb : Task failed with failed status
          ERROR -- ProcessingTask - test_file_item.rb : Task failed with failed status
          ERROR -- ProcessingTask - test_work_item.rb : Task failed with failed status
          ERROR -- ProcessingTask - TestJob : 3 subitem(s) failed
           INFO -- Run-2 - TestJob : Running subtask (3/3): FinalTask
           INFO -- FinalTask : Final processing of test_dir_item.rb
           INFO -- FinalTask : Final processing of test_file_item.rb
           INFO -- FinalTask : Final processing of test_work_item.rb
          ERROR -- Run-2 - TestJob : 1 subtask(s) failed
           INFO -- Run-2 - TestJob : Failed
        STR

        check_status_log run.status_log, [
          { task: 'Run-2', status: :failed, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :failed, progress: 3, max: 3 },
          { task: 'FinalTask', status: :done, progress: 3, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :failed },
          { task: 'FinalTask', status: :done },
          { task: 'ProcessingTask', status: :failed },
          { task: 'FinalTask', status: :done }
        ]
      end
    end

    context 'when stopped with error' do
      let(:processing) { 'error' }

      it 'should run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- Run-1 - TestJob : Ingest run started.
           INFO -- Run-1 - TestJob : Running subtask (1/3): CollectFiles
           INFO -- Run-1 - TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - test_dir_item.rb : Task failed with WorkflowError exception
          ERROR -- ProcessingTask - TestJob : Error processing subitem (1/3): Task failed with WorkflowError exception
          ERROR -- ProcessingTask - test_file_item.rb : Task failed with WorkflowError exception
          ERROR -- ProcessingTask - TestJob : Error processing subitem (2/3): Task failed with WorkflowError exception
          ERROR -- ProcessingTask - test_work_item.rb : Task failed with WorkflowError exception
          ERROR -- ProcessingTask - TestJob : Error processing subitem (3/3): Task failed with WorkflowError exception
          ERROR -- ProcessingTask - TestJob : 3 subitem(s) failed
           INFO -- Run-1 - TestJob : Running subtask (3/3): FinalTask
           INFO -- FinalTask : Final processing of test_dir_item.rb
           INFO -- FinalTask : Final processing of test_file_item.rb
           INFO -- FinalTask : Final processing of test_work_item.rb
          ERROR -- Run-1 - TestJob : 1 subtask(s) failed
           INFO -- Run-1 - TestJob : Failed
        STR

        check_status_log run.status_log, [
          { task: 'Run-1', status: :failed, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :failed, progress: 3, max: 3 },
          { task: 'FinalTask', status: :done, progress: 3, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :failed },
          { task: 'FinalTask', status: :done }
        ]
      end
    end

    context 'when stopped with abort' do
      let(:processing) { 'abort' }

      it 'should run final task' do
        run

        check_output logoutput, <<~STR
           INFO -- Run-1 - TestJob : Ingest run started.
           INFO -- Run-1 - TestJob : Running subtask (1/3): CollectFiles
           INFO -- Run-1 - TestJob : Running subtask (2/3): ProcessingTask
          ERROR -- ProcessingTask - test_dir_item.rb : Task failed with WorkflowAbort exception
          FATAL -- ProcessingTask - TestJob : Fatal error processing subitem (1/3): Task failed with WorkflowAbort exception
          ERROR -- ProcessingTask - TestJob : 1 subitem(s) failed
           INFO -- Run-1 - TestJob : Running subtask (3/3): FinalTask
           INFO -- FinalTask : Final processing of test_dir_item.rb
           INFO -- FinalTask : Final processing of test_file_item.rb
           INFO -- FinalTask : Final processing of test_work_item.rb
          ERROR -- Run-1 - TestJob : 1 subtask(s) failed
           INFO -- Run-1 - TestJob : Failed
        STR

        check_status_log run.status_log, [
          { task: 'Run-1', status: :failed, progress: 3, max: 3 },
          { task: 'CollectFiles', status: :done, progress: 3, max: 3 },
          { task: 'ProcessingTask', status: :failed, progress: 1, max: 3 },
          { task: 'FinalTask', status: :done, progress: 3, max: 3 }
        ]

        check_status_log job.items.first.status_log, [
          { task: 'CollectFiles', status: :done },
          { task: 'ProcessingTask', status: :failed },
          { task: 'FinalTask', status: :done }
        ]
      end
    end
  end
end
