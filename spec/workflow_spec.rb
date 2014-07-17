# encoding: utf-8

require 'rspec'
require 'stringio'

require_relative 'spec_helper'

describe 'TestWorkflow' do

  before do
    $:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

    require 'LIBIS_Workflow'

    @logoutput = StringIO.new

    ::LIBIS::Workflow.configure do |cfg|
      cfg.itemdir = File.join(File.dirname(__FILE__), 'items')
      cfg.taskdir = File.join(File.dirname(__FILE__), 'tasks')
      cfg.workdir = File.join(File.dirname(__FILE__), 'work')
      cfg.logger = Logger.new @logoutput
      cfg.logger.level = Logger::DEBUG
    end

    @workflow = ::LIBIS::Workflow::Workflow.new(
        tasks: [
            { class: 'CollectFiles' },
            {
                name: 'ProcessFiles',
                tasks: [
                    { class: 'ChecksumTester' },
                    { class: 'CamelizeName' }
                ]
            }
        ],
        start_object: 'TestDirItem',
        input: {
            dirname: { default: '.' }
        }
    )

    @workflow2 = ::LIBIS::Workflow::Workflow.new(
        tasks: [
            { class: 'CollectFiles' },
            {
                name: 'ProcessFiles',
                tasks: [
                    { class: 'ChecksumTester' },
                    { class: 'CamelizeName' }
                ],
                options: {
                    per_item: true
                }
            }
        ],
        start_object: 'TestDirItem',
        input: {
            dirname: { default: '.' }
        }
    )



  end

  it 'should contain two tasks' do

    expect(@workflow.tasks.size).to eq 3
    expect(@workflow.tasks.first[:class]).to eq CollectFiles
    expect(@workflow.tasks.last[:class]).to eq ::LIBIS::Workflow::Tasks::Analyzer

  end

  it 'should camelize the workitem name' do

    @workflow.run(dirname: 'spec/items')
    expect(@workflow.workitem.dirname).to eq 'spec/items'
    expect(@workflow.workitem.items.count).to eq 2
    expect(@workflow.workitem.items[0].class).to eq TestFileItem
    expect(@workflow.workitem.items[1].class).to eq TestFileItem

    sample_out = <<STR
D, [2014-07-17T19:49:36.787179 #12276] DEBUG -- CollectFiles - spec/items : Started
D, [2014-07-17T19:49:36.788389 #12276] DEBUG -- CollectFiles - spec/items : Completed
D, [2014-07-17T19:49:36.788518 #12276] DEBUG -- ProcessFiles - spec/items : Started
D, [2014-07-17T19:49:36.788654 #12276] DEBUG -- ProcessFiles - spec/items : Running subtask (1/2): ChecksumTester
D, [2014-07-17T19:49:36.788733 #12276] DEBUG -- ProcessFiles/ChecksumTester - spec/items : Processing subitem (1/2): spec/items/test_file_item.rb
D, [2014-07-17T19:49:36.788839 #12276] DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_file_item.rb : Started
D, [2014-07-17T19:49:36.788980 #12276] DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_file_item.rb : Completed
D, [2014-07-17T19:49:36.789063 #12276] DEBUG -- ProcessFiles/ChecksumTester - spec/items : Processing subitem (2/2): spec/items/test_dir_item.rb
D, [2014-07-17T19:49:36.789153 #12276] DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_dir_item.rb : Started
D, [2014-07-17T19:49:36.789272 #12276] DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_dir_item.rb : Completed
D, [2014-07-17T19:49:36.789342 #12276] DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_dir_item.rb : 2 of 2 items passed
D, [2014-07-17T19:49:36.789404 #12276] DEBUG -- ProcessFiles - spec/items : Running subtask (2/2): CamelizeName
D, [2014-07-17T19:49:36.789488 #12276] DEBUG -- ProcessFiles/CamelizeName - spec/items : Processing subitem (1/2): spec/items/test_file_item.rb
D, [2014-07-17T19:49:36.789569 #12276] DEBUG -- ProcessFiles/CamelizeName - spec/items/test_file_item.rb : Started
D, [2014-07-17T19:49:36.789710 #12276] DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestFileItem.rb : Completed
D, [2014-07-17T19:49:36.789786 #12276] DEBUG -- ProcessFiles/CamelizeName - spec/items : Processing subitem (2/2): spec/items/test_dir_item.rb
D, [2014-07-17T19:49:36.789876 #12276] DEBUG -- ProcessFiles/CamelizeName - spec/items/test_dir_item.rb : Started
D, [2014-07-17T19:49:36.789973 #12276] DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestDirItem.rb : Completed
D, [2014-07-17T19:49:36.790040 #12276] DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestDirItem.rb : 2 of 2 items passed
D, [2014-07-17T19:49:36.790107 #12276] DEBUG -- ProcessFiles - spec/items : Completed
STR
    sample_out = sample_out.lines

    output = @logoutput.string.lines
    # puts output

    expect(sample_out.count).to eq output.count
    output.each_with_index do |o, i|
      expect(o).to match Regexp.escape(sample_out[i][40..-1])
    end

  end

  it 'should run subtasks first' do

    @workflow2.run(dirname: 'spec/items')
    sample_out = <<STR
D, [2014-07-17T19:56:58.205408 #12404] DEBUG -- CollectFiles - spec/items : Started
D, [2014-07-17T19:56:58.205838 #12404] DEBUG -- CollectFiles - spec/items : Completed
D, [2014-07-17T19:56:58.205949 #12404] DEBUG -- ProcessFiles - spec/items : Started
D, [2014-07-17T19:56:58.206046 #12404] DEBUG -- ProcessFiles - spec/items : Processing subitem (1/2): spec/items/test_file_item.rb
D, [2014-07-17T19:56:58.206218 #12404] DEBUG -- ProcessFiles - spec/items/test_file_item.rb : Running subtask (1/2): ChecksumTester
D, [2014-07-17T19:56:58.206332 #12404] DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_file_item.rb : Started
D, [2014-07-17T19:56:58.206477 #12404] DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_file_item.rb : Completed
D, [2014-07-17T19:56:58.206549 #12404] DEBUG -- ProcessFiles - spec/items/test_file_item.rb : Running subtask (2/2): CamelizeName
D, [2014-07-17T19:56:58.206650 #12404] DEBUG -- ProcessFiles/CamelizeName - spec/items/test_file_item.rb : Started
D, [2014-07-17T19:56:58.206770 #12404] DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestFileItem.rb : Completed
D, [2014-07-17T19:56:58.206854 #12404] DEBUG -- ProcessFiles - spec/items : Processing subitem (2/2): spec/items/test_dir_item.rb
D, [2014-07-17T19:56:58.206997 #12404] DEBUG -- ProcessFiles - spec/items/test_dir_item.rb : Running subtask (1/2): ChecksumTester
D, [2014-07-17T19:56:58.207086 #12404] DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_dir_item.rb : Started
D, [2014-07-17T19:56:58.207257 #12404] DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_dir_item.rb : Completed
D, [2014-07-17T19:56:58.207332 #12404] DEBUG -- ProcessFiles - spec/items/test_dir_item.rb : Running subtask (2/2): CamelizeName
D, [2014-07-17T19:56:58.207419 #12404] DEBUG -- ProcessFiles/CamelizeName - spec/items/test_dir_item.rb : Started
D, [2014-07-17T19:56:58.207511 #12404] DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestDirItem.rb : Completed
D, [2014-07-17T19:56:58.207595 #12404] DEBUG -- ProcessFiles - spec/items : Completed
STR
    sample_out = sample_out.lines

    output = @logoutput.string.lines
    # puts output

    expect(sample_out.count).to eq output.count
    output.each_with_index do |o, i|
      expect(o).to match Regexp.escape(sample_out[i][40..-1])
    end

  end

end