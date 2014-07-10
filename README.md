[![Build Status](https://travis-ci.org/libis/workflow.svg?branch=master)](https://travis-ci.org/libis/workflow)
[![Coverage Status](https://coveralls.io/repos/libis/workflow/badge.png)](https://coveralls.io/r/libis/workflow)

# LIBIS Workflow

LIBIS Workflow framework

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'LIBIS_Workflow'
```


And then execute:

    $ bundle

Or install it yourself as:

    $ gem install LIBIS_Workflow

## Architecture

This gem is essentially a simple, custom workflow system. The core of the workflow are the tasks. You can - and should -
create your own tasks by creating new classes derived from ::LIBIS::Workflow::Task. The ::LIBIS::Workflow::Task class and
the included ::LIBIS::Workflow::Base class provide the necessary attributes and methods to make them work in the workflow.
See the detailed documentation for the classes for more information.

The objects that the tasks will be working on should derive from the ::LIBIS::Workflow::WorkItem class. When working with
file objects the module ::LIBIS::Workflow::FileItem module can be included for additional file-specific functionality.
Work items can be organized in different types and a hierarchical structure.

All the tasks will be organized into a ::LIBIS::Workflow::Workflow which will be able to execute the tasks in proper order
on all the WorkItems supplied/collected. Each task can be implemented with code to run or simply contain a list of child
tasks.

Two tasks are predefined:
::LIBIS::Workflow::Tasks::VirusChecker - runs a virus check on each WorkItem that is also a FileItem.
::LIBIS::Workflow::Tasks::Analyzer - analyzes the workflow run and summarizes the results. It is always included as the
last task by the workflow unless you supply a closing task called 'Analyzer' yourself.

The whole ingester workflow is configured by a Singleton object ::LIBIS::Workflow::Config which contains settings for
logging, paths where tasks and workitems can be found and the path to the virus scanner program.

## Usage

You should start by including the following line in your source code:

```ruby
require 'LIBIS_Workflow'
```

This will load all of the LIBIS Workflow framework into your environment, but including only the required parts is OK as well. This
is shown in the examples below.

### Work items

Creating your own work items is highly recommended and is fairly easy:

```ruby
require 'libis/workflow/workitems'

class MyWorkItem < ::LIBIS::Workflow::WorkItem

  attr_accesor :name

  def initialize
    @name = 'My work item'
    super # Note: this is important as the base class requires some initialization
  end

end
```

Work items that are file-based should also include the ::LIBIS::Workflow::FileItem module:

```ruby
require 'libis/workflow/workitems'

class MyFileItem < ::LIBIS::Workflow::WorkItem
  include ::LIBIS::Workflow::FileItem

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

Tasks should inherit from ::LIBIS::Workflow::Task and specify the actions it wants to
perform on each work item:

```ruby
class MyTask < ::LIBIS::Workflow::Task
  def process_item(item)
    item.perform_my_action
  rescue Exception => e
    item.set_status(to_status(:failed))
  end

end
```

You have two options to specify the actions:

### performing an action on each child item of the provided work item

In that case the task should provide a 'process_item' method as above. Each child item will be passed as the argument
to the method and perform whatever needs to be done on the item.

If the action fails the method is expected to set the item status field to failed. This is also shown in the previous
example. If the error is so severe that no other child items should be processed, the action can decide to throw an
exception, preferably a ::LIBIS::Workflow::Exception or a child exception thereof.
  
### performing an action on the provided work item

If the task wants to perform an action on the work item directly, it should define a 'process' method. The work item is
available to the method as class instance variable '@workitem'. Again the method is responsible to communicate errors
with a failed status or by throwing an exception.

### combining both

It is possible to perform some action on the parent work item first and then process each child item. Processing the
child items should be done in process_item as usual, but processing the parent item can be done either by defining a
pre_process method or a process method that ends with a 'super' call. Using this should be an exception as it is
recommended to create a seperate task to process the child work items.

### default behaviour

The default implementation of 'process' is to call 'pre_process' and then call 'process_item' on each child item.

The default implementation for 'process_item' is to run each child task for each given child item. 

### convenience functions

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

#### (debug/info/warn/error/fatal)(message, *args)

Convenience function for creating log entries. The logger set in ::LIBIS::Workflow::Config is used to dump log messages.

The first argument is mandatory and can be:
* an integer. The integer is used to look up the message text in ::LIBIS::Workflow::MessageRegistry.
* a static string. The message text is used as-is.
* a string with placement holders as used in String#%. Args can either be an array or a hash. See also Kernel#sprintf.

The log message is logged to the general logging and attached to the current work item (@workitem) unless another
work item is passed as first argument after the message.

#### check_item_type(klass, item = nil)

Checks if the work item is of the given class. @workitem is checked if the item argument is not present. If the check 
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

