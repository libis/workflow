# encoding: utf-8
require 'date'
require 'time'
require 'libis/workflow/extend/struct'

module LIBIS
  module Workflow

    # noinspection RubyConstantNamingConvention
    Parameter = ::Struct.new(:name, :default, :datatype, :description, :propagate_to) do

      TRUE_BOOL = %w'true yes t y 1'
      FALSE_BOOL = %w'false no f n 0'

      def parse(v)
        return send(:default) if v.nil?
        dtype = guess_datatype.to_s.downcase
        case dtype
          when 'date'
            return Time.parse(v).to_date
          when 'time'
            return Time.parse(v).to_time
          when 'datetime'
            return Time.parse(v).to_datetime
          when 'boolean', 'bool'
            return true if TRUE_BOOL.include?(v.to_s.downcase)
            return false if FALSE_BOOL.include?(v.to_s.downcase)
            raise ArgumentError, "No boolean information in '#{v.to_s}'. Valid values are: '#{TRUE_BOOL.join('\', \'')}' and '#{FALSE_BOOL.join('\', \'')}'."
          when 'string'
            return v.to_s.gsub('%s', Time.now.strftime('%Y%m%d%H%M%S'))
          else
            raise RuntimeError, "Datatype not supported: 'dtype'"
        end
      end

      def guess_datatype
        return send(:datatype) if send(:datatype)
        case send(:default)
          when TrueClass, FalseClass
            'bool'
          when NilClass
            'string'
          else
            send(:default).class.name
        end
      end

    end

  end
end
