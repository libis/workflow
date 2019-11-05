# frozen_string_literal: true

class TestRun

  include Libis::Workflow::Run

  attr_accessor :name
  attr_accessor :config

  attr_reader :job
  attr_reader :options
  attr_reader :properties

  def initialize(name, job, *args)
    @name = name
    @job = job
    @options = args.extract_options!
    @properties = args.extract_options!
    @config = args.extract_options!
  end

  def save!
    # not needed
  end

end
