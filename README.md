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
To see the messages sent by the shell process:
```elixir
Dbg.trace(:send)
```
Clear all trace flags for current process:
```elixir
Dbg.clear()
```
To trace a call, add the `:call` trace flag to a process:
```elixir
Dbg.trace(self(), :call)
```
Then add the function to traced calls:
```elixir
Dbg.call(&Map.new/0)
```
Call the function to see a trace message:
```elixir
Map.new()
```
Cancel tracing for `Map.new/0`:
```elixir
Dbg.cancel(&Map.new/0)
```
And clear the trace flags for `self()`:
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
def application() do
  [applications: [:dbg]]
end

def deps() do
  [{:dbg, github: "fishcakez/dbg"}]
end
```

## Compatibility With Erlang

`Dbg` is a wrapper around OTP's `:dbg` module from the `:runtime_tools`
application. `:dbg` functions will work as normal and can be combined
with `Dbg` function calls.


## License

Copyright 2014 James Fish

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
