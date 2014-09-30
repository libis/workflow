# encoding: utf-8
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rspec'

require 'libis/workflow'
require_relative 'spec_helper'

describe 'Task' do

  it 'should create a default task' do

    task = ::LIBIS::Workflow::Task.new nil

    expect(task.parent).to eq nil
    expect(task.name).to eq 'Task'
    expect(task.options[:abort_on_error]).to eq false

  end

end