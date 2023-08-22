.. default-role:: code


######################
 Plans for the plugin
######################


Launching the REPL
##################

There are a number of ways the client could connect to a server:

- Launch the application with the server
- Connect to an existing server process

I want a universal command with corresponding sub-commands, something like
this:

.. code:: vim

   FennelRepl launch love . --repl
   FennelRepl connect localhost 7070

The first one would launch a process (`jobstart`) and communicate via its
standard IO.  In the above example the application is Love2D (`love`) with the
current directory and a hypothetical custom `--repl` command-line option.  The
second one connects to an already running process via a TCP/IP socket

It might be necessary to pass additional options to the sub-command.  For such
cases we need a separator.  We can use `--`, as is common to many command-line
applications.  Example:

.. code:: vim

   FennelRepl launch --upgrade    -- love . --repl
   FennelRepl launch --no-upgrade -- love . --repl

Here we can use the `--[no-]upgrade` option to tell the plugin whether it
should upgrade the server REPL first.

New sub-commands
================

It should be possible for users to define their own sub-commands.  Each
implementation must handle its own arguments.  This includes things like the
`--` argument separator.  Example:

.. code:: lua

   -- Shorthand for launching the current Love2D project
   fennel_repl.subcommands['love'] = function love(args)
      local launch_args = vim.fn.extendnew({'launch', '--', 'love', '.'}, args)
      fennel_repl.subcommands['launch'](launch_args)
   end
