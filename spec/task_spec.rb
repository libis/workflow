require_relative 'spec_helper'

require 'libis/workflow/task'

describe 'Task' do

  it 'should create a default task' do

    task = ::Libis::Workflow::Task.new nil

    expect(task.parent).to eq nil
    expect(task.name).to eq 'Task'

  end

end