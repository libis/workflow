# frozen_string_literal: true

class TestRun

  include Libis::Workflow::Run

  attr_accessor :name
  attr_accessor :options

  attr_reader :job
  attr_reader :properties

  def initialize(name, job)
    @name = name
    @job = job
    @options = {}
    @properties = {}
  end

  def save!
    # not needed
  end

end
