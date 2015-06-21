# encoding: utf-8

require 'fileutils'

require 'libis/workflow/workitems/work_item'

module Libis
  module Workflow
    module Base
      module Run
        include ::Libis::Workflow::WorkItem

        def start_date; raise RuntimeError.new "Method not implemented: #{caller[0]}"; end
        def start_date=(_); raise RuntimeError.new "Method not implemented: #{caller[0]}"; end

        def tasks; raise RuntimeError.new "Method not implemented: #{caller[0]}"; end
        def tasks=(_); raise RuntimeError.new "Method not implemented: #{caller[0]}"; end

        def workflow; raise RuntimeError.new "Method not implemented: #{caller[0]}"; end

        def work_dir
          dir = File.join(Config.workdir, self.name)
          FileUtils.mkpath dir unless Dir.exist?(dir)
          dir
        end

        def name
          self.workflow.run_name(self.start_date)
        end

        def names
          Array.new
        end

        def namepath
          self.name
        end

        def run(opts = {})

          self.start_date = Time.now

          self.options = workflow.prepare_input(self.options.merge(opts))

          self.tasks = self.workflow.tasks(self)
          configure_tasks self.options

          self.status = :STARTED

          self.tasks.each do |task|
            next if self.failed? and not task.parameter(:always_run)
            task.run self
          end

          self.status = :DONE unless self.failed?

        end

        protected

        def configure_tasks(opts)
          self.tasks.each { |task| task.apply_options opts }
        end

      end
    end
  end
end
