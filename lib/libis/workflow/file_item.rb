# frozen_string_literal: true

require 'libis/tools/checksum'

module Libis
  module Workflow
    module FileItem

      include WorkItem

      def fullpath
        properties[:filename] || name
      end

      def filename
        File.basename(fullpath)
      end

      def filename=(file)
        delete_file
        properties[:filename] = file
        self.name ||= File.basename(file)

        return unless File.exist?(file)

        stats = ::File.stat file
        properties[:size] = stats.size
        properties[:modification_time] = stats.mtime

        add_checksum :MD5
      end

      def own_file(v = true)
        properties[:owns_file] = v
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

      def key_names
        %i'filename size modification_time owns_file'
      end

      def delete_file
        if properties[:owns_file] && fullpath
          File.delete(fullpath) if File.exists?(fullpath)
        end
        properties.keys
            .select { |key| key_names.include?(key) || key.to_s =~ /^checksum_/ }
            .each { |key| properties.delete(key) }
      end

    end
  end
end
