.. default-role:: code

########################
 Fennel REPL for Neovim
########################

This is an interactive `Fennel`_ REPL plugin for Neovim.  It allows evaluating
arbitrary Fennel expressions in a running process.  The expression is sent to
the application, evaluated, and the result is sent back to Neovim.

.. warning::

   This plugin executes arbitrary code.  Do not start a REPL automatically.  Do
   not run code you do not trust.  There is no sandboxing going on here, what
   you enter will be executed.


Installation and setup
######################

Requires Fennel 1.3.1 or higher running in the application you want to connect
to.

Install this plugin like any other Neovim plugin, then make sure the
`_protocol` Git submodule has been initialised and checkout precisely to the
version of this plugin.  The plugin communicates with the REPL process through
a protocol, and the submodule ships an implementation of said protocol.
Therefore it is important to keep the plugin and protocol implementation
synchronised.

If you were doing it by hand you would do execute these commands:

.. code:: sh

   git clone --recurse-submodules https://gitlab.com/HiPhish/fennel-repl.nvim.git

To check out the correct version of the submodule:

.. code:: sh

   git submodule update --checkout _protocol

If you are using a package manager please refer to its documentation on how to
manage submodules.

Installation
============

Install it like any other Neovim plugin.  You do not need Fennel installed, but
the application you want to hook up to has to expose some sort of Fennel REPL
over standard IO. If it does not (e.g. Löve2D) you have to write code to expose
the REPL yourself.

Setup
=====

Execute `:Fennel start <fennelprg> <arg>...` (e.g. `Fennel start love .
--repl`) to start the process which exposes a Fennel REPL over its standard IO.
This command might change in the future!

Auto completion
===============

A source named `fennel-repl` for `nvim-cmp`_ is included for convenience.  This
source will probably become its own plugin in the future, so do not rely on it
being here.


Status of the plugin
####################

The public interface of the plugin will change.  Do not rely on it.

The following functionality is available:

- Evaluate Fennel expressions (like the command-line REPL)
- Execute comma-commands (like the command-line REPL)
- Interactive stack trace
- Syntax highlighting (only regular Vim highlighting no Tree-sitter)
- Auto-completion and symbol documentation
- Reloading modules from buffers
- Buffer expression evaluation

What would be nice to have:

- REPL history
- Ability to connect to a running process instead of starting a new one; this
  would also require the ability to "downgrade" the REPL and disconnect without
  terminating the process
- Ability to register new comma-commands
- Ability to define new sub-commands
- Option like `--no-upgrade` to not upgrade the REPL (maybe not a good idea?)
- Auto-completion does not include the type of the completion item (probably
  not useful with CMP because the type of an object does not map onto an LSP
  completion type)

Wishlist
========

I don't know if the following are even possible, but here is a list of what
else I would really like to see.

Value inspector
---------------

A (floating?) window which lets the user view a table, dig into its values, and
alter them.  Metatables might complicate this because they allow overwriting
functionality like indexing.  There is also the question as to how to inspect
values local to a module.

Debug adapter
-------------

When execution hits an error or breakpoint the REPL send a message to the
editor to start debugging.  The editor then attaches to the debug adapter
inside the REPL and the two start a debug session.  This would require that the
editor upload the necessary code to the REPL after initialization.  Then
whenever a breakpoint is set the editor sends a "breakpoint" message to the
REPL so it can install the corresponding hook.

Neovim REPL
-----------

Currently the REPL runs inside a separate process.  For Neovim it would make
sense if the REPL was running right inside the editor itself.  This would
require a different class of REPL which does not wrap around a job.

Test runner
-----------

Integrate with a test runner plugin.  I am not sure if this is really a good
idea though, tests are meant to run in isolation.


License
#######

Licensed under the MIT (Expat) license. Please see the `LICENSE`_ file for
details.


See also
########

This plugin is inspired by the REPL plugin for Emacs.  Relevant links:

- https://gitlab.com/andreyorst/fennel-proto-repl-protocol
- https://andreyor.st/posts/2023-03-25-implementing-a-protocol-based-fennel-repl-and-emacs-client/
- https://andreyor.st/posts/2023-04-08-new-fennel-proto-repl-and-call-for-testing/
- https://wiki.fennel-lang.org/Repl


.. _Fennel: https://fennel-lang.org/
