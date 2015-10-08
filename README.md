
[![Build Status](https://travis-ci.org/Kris-LIBIS/workflow.svg?branch=master)](https://travis-ci.org/Kris-LIBIS/workflow)
[![Coverage Status](https://img.shields.io/coveralls/Kris-LIBIS/workflow.svg)](https://coveralls.io/r/Kris-LIBIS/workflow)

# LIBIS Workflow

LIBIS Workflow framework

## Installation

Add this line to your application's Gemfile:

```ruby
    gem 'libis-workflow'
```


And then execute:

    $ bundle

Or install it yourself as:

    $ gem install 'libis-workflow'

## Architecture

This gem is essentially a simple, custom workflow system. The core of the workflow are the tasks. You can - and should -
create your own tasks by creating new classes inherited from ::Libis::Workflow::Task. The ::Libis::Workflow::Task class
and the included ::Libis::Workflow::Base::Logger module provide the necessary attributes and methods to make them work
in the workflow. See the detailed documentation for the class and module for more information.

The objects that the tasks will be working on should include the ::Libis::Workflow::Base::WorkItem module.
When working with file objects the module ::Libis::Workflow::Base::FileItem and/or ::Libis::Workflow::Base::DirItem 
modules should be included for additional file-specific functionality.
Work items can be organized in different types and a hierarchical structure. A simple implementation of work items with
in-memory storage is provided as classes ::Libis::Workflow::WorkItem, ::Libis::Workflow::FileItem and 
::Libis::Workflow::DirItem. 

All the tasks will be organized into a workflow object for which a base module ::Libis::Workflow::Base::Workflow is
provided. It contains all the basic logic required for proper configuration and operation. Again a in-memory 
implementation is provided in the class ::Libis::Workflow::Workflow for your convenience to be used as-is or to derive
your own from.

The workflow object will be able to execute the tasks in proper order on all the WorkItems supplied/collected. Each 
task can be implemented with code to run or simply contain a list of child tasks. When a workflow is executed a special
run object is created that captures the configuration, logs and workitems generated while executing the tasks. Essential
logic is provided in the module ::Libis::Workflow::Base::Run with a simple in-memory implementation in 
::Libis::Workflow::Run. The run object's class name has to be provided to the workflow configuration so that the 
workflow can instantiate the correct object.

One tasks is predefined:
::Libis::Workflow::Tasks::Analyzer - analyzes the workflow run and summarizes the results. It is always included as the
last task by the workflow unless you supply a closing task called 'Analyzer' yourself.

The whole ingester workflow is configured by a Singleton object ::Libis::Workflow::Config which contains settings for
logging and paths where tasks and workitems can be found.

## Usage

You should start by including the following line in your source code:

```ruby
    require 'libis-workflow'
```

This will load all of the Libis Workflow framework into your environment, but including only the required parts is OK as
well. This is shown in the examples below.

### Workflows

An implementation of ::Libis::Workflow::Base::Workflow contains the definition of a workflow. Once instantiated, it can 
be run by calling the 'run' method. This will create an intance of an implementation of ::Libis::Workflow::Base::Run, 
configure it and call the 'run' method on it. The Workflow constructor takes no arguments, but is should be configured 
by calling the 'configure' method with the workflow configuration as an argument. The 'run' method takes an option Hash 
as argument.

#### Workflow configuration

A workflow configuration is a Hash with:
* name: String to identify the workflow
* description: String with detailed textual information
* tasks: Array of task descriptions
* run_object: String with class name of the ::Libis::Workflow::Base::Run implementation to be created. An istance of 
  this class will be created for each run and serves as the root work item for that particular run. 
* input: Hash with input variable definitions

##### Task description
 
is a Hash with:
* class: String with class name of the task
* name: String with the name of the task
* tasks: Array with task definitions of sub-tasks
* any task parameter values. Each task can define parameters that configure the task. It is using the 
  ::Libis::Tools::Parameter class for this.
  
The ::Libis::Workflow::Task base class allready defines the following parameters:
* quiet: Prevent generating log output. Default: false
* abort_on_error: Stop all tasks when an error occurs. Default: false
* always_run: Run this task, even if the item failed a previous task. Default: false
* subitems: Do not process the given item, but only the subitems. Default: false
* recursive: Run the task on all subitems recursively. Default: false

If 'class' is not present, the default '::Libis::Workflow::Task' with the given name will be instantiated, which simply
iterates over the child items of the given work item and performs each sub-task on each of the child items. If a 'class'
value is given, an instance of that class will be created and the task will be handed the work item to process on. See 
the chapter on 'Tasks' below for more information on tasks.

##### Input variable definition

The input variables define parameters for the workflow. When a workflow is run, it can give values for any of these
input variable and the workflow run will use the new values instead of the defaults.

The key of the input Hash is the unique name of the variable. The value is another Hash with the parameter definition.
See ::Libis::Tools::Parameter for the content of this Hash.

An additional property of the parameters is the 'propagate_to' property. It defines how the workflow run should push 
the values set for the input parameters to the parameters on the tasks. These task parameters can be addressed by a 
'<Task class or Task name>[#<parameter name>]' string. If necessary the task class or name may be specified as a full 
path with '/' separators. The parameter name part is optional and considered to be the same as the input parameter name 
if absent.

#### Run-time configuration

The 'run' method takes an optional Hash as argument which will complement and override the options Hash described in the
previous chapter.
 
Once the workflow is configured and the root work item instantiated, the method will run each top-level task on the root
work item in sequence until all tasks have completed successfully or a task has failed.

### Work items

Creating your own work items is highly recommended and is fairly easy:

```ruby

    require 'libis/workflow'

    class MyWorkItem < ::Libis::Workflow::WorkItem
      attr_accesor :name

      def initialize
        @name = 'My work item'
        super # Note: this is important as the base class requires some initialization
      end
    end
```

or if a custom storage implementation is desired, a number of data items and methods require implementation:

```ruby

    require 'libis/workflow'

    class MyWorkItem < MyStorageItem 
      include ::Libis::Workflow::Base::WorkItem

      stored_attribute :parent
      stored_attribute :items
      stored_attribute :options
      stored_attribute :properties
      stored_attribute :log_history
      stored_attribute :status_log
      stored_attribute :summary

      def initialize
        self.parent = nil
        self.items = []
        self.options = {}
        self.properties = {}
        self.log_history = []
        self.status_log = []
        self.summary = {}
      end

      protected

      def add_log_entry(msg)
        self.log_history << msg.merge(c_at: ::Time.now)
      end

      def add_status_log(message, tasklist = nil)
        self.status_log << { timestamp: ::Time.now, tasklist: tasklist, text: message }.cleanup
      end

      def status_label(status_entry)
        "#{status_entry[:tasklist].last rescue nil}#{status_entry[:text] rescue nil}"
      end

    end
```

Work items that are file-based can derive from the ::Libis::Workflow::FileItem class:

```ruby

    require 'libis/workflow'

    class MyFileItem < ::Libis::Workflow::FileItem

      def initialize(file)
        filename = file
        super
      end

      def filesize
        properties[:size]
      end

      def fixity_check(checksum)
        properties[:checksum] == checksum
      end

    end
```

or include the ::Libis::Workflow::Base::FileItem module:

```ruby

    require 'libis/workflow'

    class MyFileItem < MyWorkItem 
      include ::Libis::Workflow::FileItem

      def initialize(file)
        filename = file
        super
      end

      def filesize
        properties[:size]
      end

      def fixity_check(checksum)
        properties[:checksum] == checksum
      end

    end
```



## Tasks

Tasks should inherit from ::Libis::Workflow::Task and specify the actions it wants to
perform on each work item:

```ruby

    class MyTask < ::Libis::Workflow::Task

      def process_item(item)
        if do_something(item)
          info "Did something"
        else
          raise ::Libis::WorkflowError, "Something went wrong" 
        end
      rescue Exception => e
        error "Fatal problem, aborting" 
        raise ::Libis::WorkflowAbort, "Fatal problem"  
      ensure
        item
      end

    end
```

As seen above, the task should define a method called process_item that takes one argument. The argument will be a 
reference to the work item that it needs to perform an action on. The task has several option to progress after 
performing its actions:
* return. This is considered a normal and successful operation result. If the item was replaced by a new item or if the 
 item tree has changed, it is recommended to return the new item. After a successful return the item's status will be 
 set to 'done' for the given task.
* raise a ::Libis::WorkflowError. Indicates that something went wrong during the processing of the item. The item's 
 status will be set to failed for the given task and the exception message will be printed in the error log. Processing 
 will continue with the next item. This action is recommended for temporary or recoverable errors.
* raise a ::Libis::WorkflowAbort. A severe and fatal error has occured. Processing will abort immediately and the 
 failure status will be escalated to all items up the item hierarchy. Due to the escalating behaviour, no message is 
 printed in the error log automatically, so it is up to the task to an appropriate log the error itself.
* raise any other Exception. Should be avoided, but if it happens nevertheless, it will cause the item to fail for the 
 given task and the exception message to be logged in the error log. It will attempt to process the other items.

### Controlling behavior with parameters

You have some options to control how the task will behave in special cases. These are controlled using parameters on 
the task, which can be set (and fixed with the 'frozen' option) on the task, but can be configured at run-time with the 
help of workflow input parameters and run options.

#### Performing an action on the work item and all child items recursively

With the 'recursive' parameter set to true, your task's process_item method will be called for the work item and then 
once for each child and each child's children recursively.
  
#### Performing an action only on the child items, skipping the work item itself

The parameter 'subitems' decides if the item handed over to the task will be processed or if it will process only it's 
child items. This will only work once, not recursively, but by organizing tasks hierarchically with 'subitems' set to 
true, it is possible to make sure that only items on a certain hierarchy level are performed. Recommended for workflows 
where a well-known and fixed hierarchical structure has to be processed selectively.

Alternatively the 'recursive' option can be set and the 'process_item' method could check for certain item types, 
properties or hierarchy levels to decide to perform the operation. This approach is more flexible but harder to 
understand unless well documented.

#### Preventing any logging output from the task

Logging output can be blocked on a task-by-task basis by setting the 'quiet' parameter to true. Probably not usefull 
except for the Analyzer task where the parameter is fixed to true. Logging output would otherwise intervene with the 
log summary processing performed by the task.

#### Aborting the task whenever any item fails
 
When a task is so critical in the workflow process that any failure renders further processing useless, the parameter 
'abort_on_error' can be turned on. Raising a ::Libis::WorkflowAbort exception would perform the same thing, but the 
parameter makes the configuration more flexible.

#### Always running a task, even on items that failed in an earlier stage in the workflow

The opposite of aborting on error, the parameter 'always_run' can be set to true to force a task to process the items 
even if the item has a failed status from a previous task. Note that this will cause the item's status to no longer be 
failing until a task fails on the item again. The old failed status will be tracable in the status history.

The parameter only configures the task on which it is set. If the task is a subtask it will only be forced to run if 
any of it's previous sibling tasks failed. In order to force the run, even if the item failed in another branch of the 
task hiearchy, the parent tasks should have their 'always_run' parameter also set to true.

### Pre- and postprocessing

The default implementation of 'process' is to call 'pre_process' and then call 'process_item' on each child item, 
followed by calling 'post_process'. The methods 'pre_process' and 'post_process' are no-operation methods by default, 
but can be overwritten if needed.

### Convenience functions

#### get_root_item()

Returns the work item that the workflow started with (and is the root/grand parent of all work items in the ingest run).

#### get_work_dir()

Returns the work directory as configured for the current ingest run. The work directory can be used as scrap directory
for creating derived files that can be added as work items to the current flow or for downloading files that will be
processed later. The work directory is not automaticaly cleaned up, which is considered a task for the workflow implementation. 

#### capture_cmd(cmd, *args)

Allows the task to run an external command-line program and capture it's stdout and stderr output at the same time. The
first argument is mandatory and should be the command-line program that has to be executed. An arbitrary number of
command-line arguments may follow.

The return value is an array with three elements: the status code returned by the command, the stdout string and the 
stderr string.

#### names()

An array of strings with the hierarchical path of tasks leading to the current task. Can be usefull for log messages.
The method 'namepath' returns a '/' separated path of tasks.

#### (debug/info/warn/error/fatal)(message, *args)

Convenience function for creating log entries. The logger set in ::Libis::Workflow::Config is used to dump log messages.

The first argument is mandatory and can be:
* an integer. The integer is used to look up the message text in ::Libis::Workflow::MessageRegistry.
* a static string. The message text is used as-is.
* a string with placement holders as used in String#%. Args can either be an array or a hash. See also Kernel#sprintf.

The log message is logged to the general logging and attached to the current work item (workitem) unless another
work item is passed as first argument after the message.

#### check_item_type(klass, item = nil)

Checks if the work item is of the given class. 'workitem' is checked if the item argument is not present. If the check 
fails a Runtime exception is thrown which will cause the task to abort if not catched. 

#### item_type?(klass, item = nil)

A less severe variant version of check_item_type which returns a boolean (false if failed).

#### to_status(status)

Simply prepends the status text with the current task name. The output of this function is typically what the work item
status field should be set at.

## Contributing

1. Fork it ( https://github.com/libis/workflow/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
