# frozen_string_literal: true

module Libis
  module Workflow
    module Base
      module TaskConfiguration

        def configure(parameter_values)
          parameter_values.each do |name, value|
            parameter(name, value)
          end
        end

        def configure_tasks(tasks)
          tasks.each do |task|
            task[:class] ||= 'Libis::Workflow::TaskGroup'
            task_obj = task[:class].constantize.new(task)
            task_obj.configure(task[:parameters])
            self << task_obj
            next unless task[:tasks]

            task_obj.configure_tasks(task[:tasks])
          end
        end

      end
    end
  end
end
