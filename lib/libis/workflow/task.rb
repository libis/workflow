# encoding: utf-8

require 'backports/rails/hash'
require 'backports/rails/string'

require 'libis/workflow/base'

module LIBIS
  module Workflow

    class Task
      include Base

      attr_reader :options

      def initialize(parent, config = {})
        set_parent parent
        @name = config[:name] || config[:class] || self.class.name
        @task_config = config[:tasks] || []

        @action = config[:action] || :START

        temp = config.dup
        temp.delete :options
        temp.delete :tasks

        @options = default_options.merge(config[:options] || {}).merge(temp).symbolize_keys!

        @config = config
      end

      def start(item)

        @workitem = item

        check_item_type WorkItem

        return if @workitem.failed? unless options[:allways_run]

        @workitem.set_status to_status :started
        debug 'Started'

        process

        unless @workitem.failed?
          debug 'Completed'
          @workitem.set_status to_status :done
        end

      rescue Exception => e
        error 'Failed (%s)', e.message
        @workitem.set_status to_status :failed

      rescue ::Exception => e
        error 'Exception occured: %s' % ([e.message] + e.backtrace).join("\n")
        @workitem.set_status to_status :failed

      end

      protected

      def default_options
        {abort_on_error: false}
      end

      def pre_process
      end

      def process

        pre_process

        failed = 0

        @item_count = 0
        @item_total = @workitem.items.size

        @workitem.each do |item|
          next if item.failed?
          @item_count += 1
          process_item(item)
          failed += 1 if item.failed?
        end

        if @workitem.items.size > 0
          warn '%s item(s) failed on %s', failed.to_s, self.name if failed > 0
          debug '%d of %d passed', @item_total - failed, @item_total
        end

        @workitem.set_status to_status :failed if failed > 0 and (@options[:abort_on_error] or failed == @item_total)

      rescue Exception => e
        error e.message
        @workitem.set_status(to_status(:failed))

      rescue ::Exception => e
        error 'Exception occured: %s', ([e.message] + e.backtrace).join("\n")
        @workitem.set_status to_status :failed

      end

      def process_item(item)

        raise RuntimeError, 'Should be overwritten' unless @task_config

        begin
          tasks = @task_config.map do |t|
            task_class = Task
            task_class = t[:class].constantize if t[:class]
            task_instance = task_class.new self, t.symbolize_keys!
            {
                class: task_class,
                instance: task_instance
            }
          end

          errors = []

          item.set_status to_status :started
          debug 'Started (%d/%d)', @item_count, @item_total

          tasks.each do |task|
            next if item.failed? and not task[:instance].options[:allways_run]
            task[:instance].start item
            errors << task[:class].name if item.failed?
          end

          if errors.size > 0
            error 'Failed due to error(s) in %s', errors.join(',')
            item.set_status to_status :failed
          else
            debug 'Complete'
            item.set_status to_status :done
          end

        rescue => e
          error 'Exception occured: %s' % ([e.message] + e.backtrace).join("\n")
          item.set_status to_status :failed

        end

      end

      def get_root_item
        root_item = @workitem
        root_item = root_item.parent until root_item.parent.nil?
        root_item
      end

      def get_work_dir
        get_root_item.get_work_dir
      end

      def capture_cmd(cmd, *opts)
        out = StringIO.new
        err = StringIO.new
        $stdout = out
        $stderr = err
        status = system cmd, *opts
        return [status, out.string, err.string]
      ensure
        $stdout = STDOUT
        $stderr = STDERR
      end

    end

  end
end
