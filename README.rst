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

Requires Fennel 1.3.1 or higher.

Installation
============

Install it like any other Neovim plugin.  You do not need Fennel installed, but
the application you want to hook up to has to expose some sort of Fennel REPL
over standard IO. If it does not (e.g. Löve2D) you have to write code to expose
the REPL yourself.

Setup
=====

Execute `:Fennel args...` (e.g. `Fennel love . --repl`) to start the process
which exposes a Fennel REPL over its standard IO.  This command will change in
the future!  For now the REPL must conform to the protocol, but later it will
be possible to upgrade the REPL.


Status of the plugin
####################

The public interface of the plugin will change.  Do not rely on it.

It works as a basic REPL: you send it text and get text back.  It is the same
as the REPL you get when you run `fennel` from the command-line.

These features are absolutely necessary for a fully working REPL:

- [X] Handling of messages sent to the process standard output
- [ ] Handling of messages received from the process standard input

There are a lot of niceties to add:

- [ ] Interactive stacktrace: click a line and get taken to that location
- [ ] Auto-completion on the REPL
- [ ] Syntax highlighting of user input (no idea how I can do that)
- [ ] Documentation lookup (e.g. when pressing `K` while on a symbol)

The following features are needed for a robust REPL experience:

- [ ] Option to upgrade a REPL which does not follow the protocol; I will
  probably have to ship the upgrade function with this plugin
- [ ] Ability to strip off a prompt received from the server
- [ ] Transmitting the formatting function to the server; JSON would be a good
  choice because Neovim can decode it, but how do I teach the server JSON?


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
