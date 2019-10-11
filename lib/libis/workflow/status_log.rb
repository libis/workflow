# frozen_string_literal: true

module Libis::Workflow::StatusLog
  ### Methods that need implementation in the including class
  # getter and setter accessors for:
  # - run
  # - item
  # - status
  # - progress
  # - max
  # class methods:
  # - create_status(...)
  # - find_last(...)
  # instance methods:
  # - update(...)

  def self.set_status(status:, task:, item: nil, progress: nil, max: nil)
    entry = send(:find_last, task: task, item: item)
    values = { status: status, task: task, item: item, progress: progress, max: max }.compact
    return send(:create_status, values) if entry.nil?
    return send(:create_status, values) if StatusEnum.to_int(status) < StatusEnum.to_int(entry.send(:status))

    entry.send(:update, values.tap { |k, _| %i[task item].include? k })
  end

  def status_sym
    StatusEnum.to_sym(send(:status))
  end

  def status_txt
    StatusEnum.to_sym(send(:status))
  end
end
