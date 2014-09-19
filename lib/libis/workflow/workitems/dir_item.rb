# encoding: utf-8

require 'libis/workflow/workitems/file_item'

module LIBIS
  module Workflow

    module DirItem
      include FileItem

      def collect(fileclass, opts = {})
        dirclass = opts[:dirclass] || self.class
        wildcard = opts[:wildcard] || '*'
        base_dir = self.long_name
        self.items.clear
        Dir.glob(File.join(base_dir, wildcard)).sort.each do |name|
          next if %w'. ..'.include? name
          if File.file? name
            file = fileclass.new
            file.name = name
            self << file
          elsif File.directory? name
            dir = dirclass.new
            dir.name = name
            self << dir
            dir.collect(fileclass, opts) if opts[:recursive]
          else
            # do nothing
          end
        end
        # puts "Dir #{self.long_name} has #{self.items.count} items"
        # self.each { |item| puts "- #{item.name}" }
      end

    end
  end
end
