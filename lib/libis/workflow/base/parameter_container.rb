# encoding: utf-8

require 'libis/workflow/parameter'

module LIBIS
  module Workflow

    module ParameterContainer

      VALID_PARAMETER_KEYS = [:name, :value, :default, :datatype, :description]
      def parameters
        @parameters ||= {}
      end

      def parameter(options = {})
        param_def = options.shift
        name = param_def.first.to_s.to_sym
        default = param_def.last
        datatype = options[:datatype]
        description = options[:description]
        parameters[name] = Parameter.new(name, default, datatype, description)
      end

      def get_parameter(name)
        parameters[name]
      end

      def get_parameters
        ancestors.inject({}) do |hash, ancestor|
          hash.merge! ancestor.parameters rescue nil
          hash
        end
      end

    end # ParameterContainer

  end # Workflow
end # LIBIS
