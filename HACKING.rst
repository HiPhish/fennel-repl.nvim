.. default-role:: code


############################
 Hacking on the Fennel REPL
############################


About the protocol
##################

The default REPL which ships with Fennel (`fennel.repl`) is only suitable for
interactive use by a human: it prints all output to the standard output and
reads all input from the standard input.  This means for example that there is
no way to distinguish output from side effects and output from evaluation of an
expression:

.. code:: fennel

   ;; These two expressions produce the same output
   (print 1)
   1

We need to teach the REPL a protocol so it can wrap output into messages which
we can distinguish by their type.  If we use JSON as our message format the two
above expressions could produce the following two messages:

- `{"id": 1, "op": "print", "descr": "stdout", "data": "1\\\\n"}`
- `{"id": 2, "op": "eval", "values": ["1"]}`

We can now clearly distinguish the different kinds of messages.  The exact
specifications of the protocol are not important at this point. What is
important though is how we can teach the REPL this protocol.


Upgrading the REPL
==================

The protocol implementation is shipped as a Git submodule. It is a function
which when called will start a new REPL on top of the existing one with custom
callback functions.  This is called “upgrading” the REPL.  But how can we send
this code over to an already running REPL process?

The running REPL can already evaluate expressions, so all we have to do is make
sure the very first expression we send over is a call to the upgrade function.
Currently I send a small Fennel expression over which loads the upgrade
function from a local file:

.. code:: fennel

   (let [{: dofile} (require :fennel)
         protocol (dofile "_protocol/protocol.fnl")
         format/json (dofile "_format/json.fnl")]
     (protocol format/json))

Actually, I use absolute file paths in the real code, but that's irrelevant
here.  However, this will only work if the REPL process is running on the same
machine.  In the future I might consider splicing the entire file contents into
this snippet.

Once the REPL has processed the protocol message it will reply with an initial
initialisation message.  At this point the protocol has been established and
the client can present the prompt buffer to the user.


About extras
############

Extras are features which are not necessary for a working REPL, but when are
useful to have.  They are like plugins, except included by default.  An extra
must not use internal features, it may only be implemented public APIs.  
