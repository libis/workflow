# encoding: utf-8

require 'digest'

module LIBIS
  module Workflow

    module FileItem

      def filename
        self.properties[:filename]
      end

      def properties
        @properties ||= {}
      end

      def set_file(name)
        self.filename = name
      end

      def filename=(name)
        begin
          stats = ::File.stat name
          self.properties[:size] = stats.size
          self.properties[:access_time] = stats.atime
          self.properties[:modification_time] = stats.mtime
          self.properties[:creation_time] = stats.ctime
          self.properties[:checksum] = ::Digest::MD5.hexdigest(File.read(name))
        rescue
          # ignored
        end
        self.properties[:filename] = name
      end

      def linkname
        self.properties[:linkname]
      end

      def linkname=(name)
        self.properties[:linkname] = name
      end

      def set_fileinfo(fileinfo)
        fileinfo.each do |k, v|
          self.properties[k] = v
        end
      end

      def to_string
        return ::File.basename(self.filename) unless self.filename.nil? or self.filename.empty?
        return self.linkname unless self.linkname.nil? or self.linkname.empty?
        self.inspect
      end

      def to_filename
        return self.filename unless self.filename.nil? or self.filename.empty?
        self.to_string.gsub(/[^\w.-]/) { |s| '%%%02x' % s.ord }
      end

    end
  end
end
