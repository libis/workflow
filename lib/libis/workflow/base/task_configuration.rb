# frozen_string_literal: true

module Libis
  module Workflow
    module Base
      module TaskConfiguration

        def configure(parameter_values)
          parameter_values.each do |name, value|
            parameter(name, value)
          end if parameter_values
        end

      end
    end
  end
end
