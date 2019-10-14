# frozen_string_literal: true

class TestJob

  include Libis::Workflow::Job

  attr_reader :workflow, :runs, :items, :name

  def initialize(name, workflow)
    @name = name
    @workflow = workflow
    @runs = []
    @items = []
  end

  def configure(input)
    @input = input
  end

  def tasks
    apply_input(workflow.config[:tasks], @input)
  end

  def make_run
    run = TestRun.new(run_name, self)
    runs << run
    run
  end

  def last_run
    runs.last
  end

  def <<(item)
    @items << item
    item.job = self
  end

  def item_list
    @items.dup
  end

  protected

  def apply_input(task_config, input)
    task_config.map do |task|
      task.each_with_object({}) do |(key, value), result|
        value = value.each_with_object({}) { |(k, v), r| r[k] = input.key?(k) ? input[k] : v } if key == :parameters
        value = apply_input(value, input) if key == :tasks
        result[key] = value
      end
    end
  end

end
