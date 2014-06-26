# Dbg

`Dbg` provides functions for tracing events in the BEAM VM.

Many events, including function calls and return, exception raising, sending
and receiving messages, spawning, exiting, linking, scheduling and garbage
collection can be traced across a cluster of nodes using `Dbg`.

## Try it out
Clone the repo:
```
git clone https://github.com/fishcakez/dbg.git
cd dbg
mix compile
iex -S mix
```
To see the messages sent my the shell process:
```elixir
Dbg.trace(:send)
```
Clear all trace flags:
```elixir
Dbg.clear()
```
To trace a call, add the `:call` flag to a process:
```elixir
Dbg.trace(self(), :call)
```
Then add the function:
```elixir
Dbg.call(&Map.new/0)
```
Call the function to see a trace:
```elixir
Map.new()
```
Cancel tracing for `Map.new/0`:
```elixir
Dbg.cancel(&Map.new/0)
```
And clear the trace flags:
```elixir
Dbg.clear(self())
```
To reset all tracing:
```elixir
Dbg.reset()
```

## Read The Docs

`Dbg` allows much more sophisticated tracing. To get the docs:
```
mix deps.get
MIX_ENV=docs mix docs
```

## Install As Dependency

As a dependency to a mix.es file:
```elixir
def deps() do
  [{:dbg, github: "fishcakez/dbg"}]
end
```

## Compatibility With Erlang

`Dbg` is a wrapper around OTP's `:dbg` module from the `:runtime_tools`
application. `:dbg` functions will work as normal and can be combined
with `Dbg` function calls.
