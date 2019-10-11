# frozen_string_literal: true

module Libis::Workflow::Base::Status
  ### Methods that need implementation in the including class
  # status_log

  # @return [Libis::Workflow::Status] status entry or nil if not found
  def find_last(task: nil, item: nil)
    task ||= self if is_a? Libis::Workflow::Task
    item ||= self if is_a? Libis::Workflow::WorkItem
    send(:status_log).find_last(task: task, item: item)
  end

  # @return [Libis::Workflow::Status] newly created status entry
  def set_status(status:, task: nil, item: nil, progress: nil, max: nil)
    task ||= self if is_a? Libis::Workflow::Task
    item ||= self if is_a? Libis::Workflow::WorkItem
    send(:status_log).set_status(status: status, task: task, item: item, progress: progress, max: max)
  end

  # Update the progress of the working task
  # @param [Integer] progress progress indicator (as <progress> of <max> or as % if <max> not set). Default: 0
  # @param [Integer] max max count.
  def status_progress(task: nil, item: nil, progress: nil, max: nil)
    task ||= self if is_a? Libis::Workflow::Task
    item ||= self if is_a? Libis::Workflow::WorkItem
    send(:status_log).set_status(task: task, item: item, progress: progress, max: max)
  end

  # Get last known status symbol for a given task and item
  # @return [Symbol] the status code
  def status(task: nil, item: nil)
    entry = find_last(task: task, item: item)
    entry&.status_sym || StatusEnum.keys.first
  end

  # Get last known status text for a given task
  # @return [String] the status text
  def status_txt(task: nil, item: nil)
    entry = find_last(task: task, item: item)
    entry&.status_txt || StatusEnum.values.first
  end

  # Gets the last known status label of the object.
  # @return [String] status label ( = task name + status )
  def status_label(task: nil, item: nil)
    "#{task}#{status(task: task, item: item).to_s.camelize}"
  end

  # Check status of the object.
  # @return [Boolean] true if the object status matches
  def check_status(state, task: nil, item: nil)
    compare_status(state, task: task, item: item).zero?
  end

  # Compare status with current status of the object.
  # @return [Integer] 1, 0 or -1 depending on which status is higher in rank
  def compare_status(state, task: nil, item: nil)
    StatusEnum.to_int(status(task: task, item: item)) <=> Status_to_int(state)
  end

end
