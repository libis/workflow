# frozen_string_literal: true

require 'libis/tools/checksum'

module Libis
  module Workflow
    module FileItem

      include WorkItem

      def name
        properties[:name] || filename
      end

      def fullpath
        properties[:filename]
      end

      def filename
        File.basename(properties[:filename])
      end

      def filename=(file)
        properties[:filename] = file

        return unless File.exist?(file)

        stats = ::File.stat file
        properties[:size] = stats.size
        properties[:access_time] = stats.atime
        properties[:modification_time] = stats.mtime
        properties[:creation_time] = stats.ctime
        properties[:mode] = stats.mode
        properties[:uid] = stats.uid
        properties[:gid] = stats.gid

        add_checksum :MD5
      end

      def filelist
        (parent&.filelist | []).push(filename).compact
      end

      def filepath
        filelist.join('/')
      end

      def checksum(checksum_type)
        properties[('checksum_' + checksum_type.to_s.downcase).to_sym]
      end

      def add_checksum(checksum_type)
        return unless File.file?(fullpath)

        set_checksum checksum_type, ::Libis::Tools::Checksum.hexdigest(fullpath, checksum_type)
      end

      def set_checksum(checksum_type, value)
        properties[('checksum_' + checksum_type.to_s.downcase).to_sym] = value
      end

      def link
        properties[:link]
      end

      def link=(name)
        properties[:link] = name
      end

      def info=(info)
        info.each do |k, v|
          properties[k] = v
        end
      end

    end
  end
end
