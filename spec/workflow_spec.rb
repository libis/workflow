# encoding: utf-8

require 'rspec'

describe 'TestWorkflow' do

  before do
    $:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

    require 'LIBIS_Workflow'

    ::LIBIS::Workflow.configure do |cfg|
      cfg.itemdir = File.join(File.dirname(__FILE__), 'items')
      cfg.taskdir = File.join(File.dirname(__FILE__), 'tasks')
      cfg.workdir = File.join(File.dirname(__FILE__), 'work')
      cfg.logger.level = ::Logger::FATAL
    end

    @workflow = ::LIBIS::Workflow::Workflow.new(tasks: [{class: 'CamelizeName'}], start_object: 'Item')

  end

  it 'should contain two tasks' do

    expect(@workflow.tasks.size).to eq 2
    expect(@workflow.tasks.last[:class]).to eq ::LIBIS::Workflow::Tasks::Analyzer

  end

  it 'should camelize the workitem name' do

    @workflow.start
    expect(@workflow.workitem.name).to eq 'TestItem'

  end

end