# encoding: utf-8

require 'digest'

require 'libis/workflow/workitems/work_item'

module LIBIS
  module Workflow

    module FileItem
      include WorkItem

      def name
        File.basename(self.properties[:name]) || self.properties[:link]
      end

      def long_name
        self.properties[:name] || self.properties[:link]
      end

      def name=(name)
        begin
          stats = ::File.stat name
          self.properties[:size] = stats.size
          self.properties[:access_time] = stats.atime
          self.properties[:modification_time] = stats.mtime
          self.properties[:creation_time] = stats.ctime
          self.properties[:mode] = stats.mode
          self.properties[:uid] = stats.uid
          self.properties[:gid] = stats.gid
          self.properties[:checksum] = ::Digest::MD5.hexdigest(File.read(name)) if File.file? name
        rescue
          # ignored
        end
        self.properties[:name] = name
      end

      def link
        self.properties[:link]
      end

      def link=(name)
        self.properties[:link] = name
      end

      def set_info(info)
        info.each do |k, v|
          self.properties[k] = v
        end
      end

      def safe_name
        self.name.to_s.gsub(/[^\w.-]/) { |s| '%%%02x' % s.ord }
      end

    end
  end
end
