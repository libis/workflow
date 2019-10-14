# frozen_string_literal: true

class TestStatusLog

  include Libis::Workflow::StatusLog

  attr_reader :status, :run, :task, :item, :progress, :max, :created_at, :updated_at

  def initialize(status, run, task, item = nil, max = nil)
    @status = status
    @run = run
    @task = task
    @item = item
    @progress = 0
    @max = max
    @updated_at = @created_at = DateTime.now
  end

  def self.create_status(status:, task:, item: nil, max: nil)
    run, task, item = sanitize(task: task, item: item)
    new_status = new status, run, task, item, max
    registry << new_status
    # ap new_status.pretty
    new_status
  end

  def self.find_last(task:, item: nil)
    run, task, item = sanitize(task: task, item: item)
    registry
        .find_all { |entry| entry.run == run && entry.task == task && entry.item == item }
        .max_by(&:updated_at)
  end

  def self.find_all(run: nil, task: nil, item: nil)
    run, task, item = sanitize(run: run, task: task, item: item)
    registry.find_all do |entry|
      (run.nil? || entry.run == run) && (task.nil? || entry.task == task) && entry.item == item
    end.sort_by(&:created_at)
  end

  def update_status(values = {})
    values.each do |key, value|
      case key
      when :status
        @status = value
      when :progress
        @progress = value
      when :max
        @max = value
      else
        raise StandardError, "ERROR: cannot update log entry value for key '#{key}'"
      end
      @updated_at = DateTime.now
    end
    # ap pretty
    self
  end

  def self.registry
    @registry ||= []
  end

  def pretty
    { status: @status, run: @run.name, task: @task, item: @item&.namepath, progress: @progress, max: @max,
      created: @created_at.strftime('%Y-%m-%d %H:%M:%S.%N'), updated: @updated_at.strftime('%Y-%m-%d %H:%M:%S.%N') }
  end

  def self.sanitize(run: nil, task: nil, item: nil)
    run ||= task.run if task
    task = task.namepath if task
    item = nil unless item.is_a? Libis::Workflow::WorkItem
    [run, task, item]
  end

end
