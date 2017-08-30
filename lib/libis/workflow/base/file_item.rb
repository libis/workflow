require 'digest'

require 'libis/workflow/base/work_item'

module Libis
  module Workflow
    module Base

      # noinspection RubyResolve
      module FileItem
        include Libis::Workflow::Base::WorkItem

        def filename
          File.basename(self.properties['filename']) || self.properties['link']
        end

        def name
          self.properties['name'] || self.filename
        end

        def filelist
          (self.parent.filelist rescue Array.new).push(filename).compact
        end

        def filepath
          self.filelist.join('/')
        end

        def fullpath
          self.properties['filename']
        end

        def filename=(name)
          begin
            stats = ::File.stat name
            self.properties['size'] = stats.size
            self.properties['access_time'] = stats.atime
            self.properties['modification_time'] = stats.mtime
            self.properties['creation_time'] = stats.ctime
            self.properties['mode'] = stats.mode
            self.properties['uid'] = stats.uid
            self.properties['gid'] = stats.gid
            set_checksum(:MD5, ::Digest::MD5.hexdigest(File.read(name))) if File.file?(name)
          rescue => _e
            # ignored
          end
          self.properties['filename'] = name
        end

        def checksum(checksum_type)
          self.properties[('checksum_' + checksum_type.to_s.downcase)]
        end

        def set_checksum(checksum_type, value)
          self.properties[('checksum_' + checksum_type.to_s.downcase)] = value
        end

        def link
          self.properties['link']
        end

        def link=(name)
          self.properties['link'] = name
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
end
