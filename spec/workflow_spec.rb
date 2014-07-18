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

  it 'should contain three tasks' do

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
DEBUG -- CollectFiles - spec/items : Started
DEBUG -- CollectFiles - spec/items : Completed
DEBUG -- ProcessFiles - spec/items : Started
DEBUG -- ProcessFiles - spec/items : Running subtask (1/2): ChecksumTester
DEBUG -- ProcessFiles/ChecksumTester - spec/items : Processing subitem (1/2): spec/items/test_dir_item.rb
DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_dir_item.rb : Started
DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_dir_item.rb : Completed
DEBUG -- ProcessFiles/ChecksumTester - spec/items : Processing subitem (2/2): spec/items/test_file_item.rb
DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_file_item.rb : Started
DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_file_item.rb : Completed
DEBUG -- ProcessFiles/ChecksumTester - spec/items : 2 of 2 items passed
DEBUG -- ProcessFiles - spec/items : Running subtask (2/2): CamelizeName
DEBUG -- ProcessFiles/CamelizeName - spec/items : Processing subitem (1/2): spec/items/test_dir_item.rb
DEBUG -- ProcessFiles/CamelizeName - spec/items/test_dir_item.rb : Started
DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestDirItem.rb : Completed
DEBUG -- ProcessFiles/CamelizeName - spec/items : Processing subitem (2/2): spec/items/test_file_item.rb
DEBUG -- ProcessFiles/CamelizeName - spec/items/test_file_item.rb : Started
DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestFileItem.rb : Completed
DEBUG -- ProcessFiles/CamelizeName - spec/items : 2 of 2 items passed
DEBUG -- ProcessFiles - spec/items : Completed
STR
    sample_out = sample_out.lines.to_a
    output = @logoutput.string.lines
    # puts output

    expect(sample_out.count).to eq output.count
    output.each_with_index do |o, i|
      expect(o[/(?<=\] ).*/]).to eq sample_out[i].strip
    end

  end

  it 'should process subitems first' do

    @workflow2.run(dirname: 'spec/items')
    sample_out = <<STR
DEBUG -- CollectFiles - spec/items : Started
DEBUG -- CollectFiles - spec/items : Completed
DEBUG -- ProcessFiles - spec/items : Started
DEBUG -- ProcessFiles - spec/items : Processing subitem (1/2): spec/items/test_dir_item.rb
DEBUG -- ProcessFiles - spec/items/test_dir_item.rb : Running subtask (1/2): ChecksumTester
DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_dir_item.rb : Started
DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_dir_item.rb : Completed
DEBUG -- ProcessFiles - spec/items/test_dir_item.rb : Running subtask (2/2): CamelizeName
DEBUG -- ProcessFiles/CamelizeName - spec/items/test_dir_item.rb : Started
DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestDirItem.rb : Completed
DEBUG -- ProcessFiles - spec/items : Processing subitem (2/2): spec/items/test_file_item.rb
DEBUG -- ProcessFiles - spec/items/test_file_item.rb : Running subtask (1/2): ChecksumTester
DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_file_item.rb : Started
DEBUG -- ProcessFiles/ChecksumTester - spec/items/test_file_item.rb : Completed
DEBUG -- ProcessFiles - spec/items/test_file_item.rb : Running subtask (2/2): CamelizeName
DEBUG -- ProcessFiles/CamelizeName - spec/items/test_file_item.rb : Started
DEBUG -- ProcessFiles/CamelizeName - Spec::Items::TestFileItem.rb : Completed
DEBUG -- ProcessFiles - spec/items : 2 of 2 items passed
DEBUG -- ProcessFiles - spec/items : Completed
STR
    sample_out = sample_out.lines.to_a
    output = @logoutput.string.lines
    # puts output

    expect(sample_out.count).to eq output.count
    output.each_with_index do |o, i|
      expect(o[/(?<=\] ).*/]).to eq sample_out[i].strip
    end

  end

end