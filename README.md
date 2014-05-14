# Dbg

`Dbg` is a convenience wrapper for `:dbg` with custom formatting of trace
messages.

```elixir
# Dbg.trace/1,2 is equivalent to :dbg.p/1,2
Dbg.trace(self(), :call)
# It also allows processes by registered name:
:global.register_name(:name, self())
Dbg.trace({ :global, :name }, :call)

# Dbg.clear/1 is equivalent to &Dbg.trace(&1, :clear)
Dbg.clear(self())

# Dbg.call/1,2 is similar to :dbg.tp/1,2:
Dbg.call({Map, :new, 0})
# The first argunment can also be an external fun:
Dbg.call(&Map.new/0)
# Or a module:
Dbg.call(Map)
# Or a tuple with just module and function name:
Dbg.call({ Map, :new })

# Dbg.call/2 takes a different second argument to :dbg.tp/2
# It can be a fun created in the shell:
Dbg.call(&Map.to_list/1, fn([map]) when is_map(map) -> [] end)
# Or a string representing a fun:
Dbg.call(&Map.to_list/1, "fn([map]) when is_map(map) -> [] end")
# Or a matchspec:
Dbg.call(&Map.to_list/1, [{[:"$1"], [is_map: :"$1"], []}])
# Or list of options, a fun, fun string or match_spec should return these
# options instead of the :dbg options.
Dbg.call(&Map.to_list/1, [:return, :caller, :stack, :exception])
# Or a single option:
Dbg.call(&Map.to_list/1, :stack)
# Or a saved pattern, using the :saved integer returned by a previous call:
Dbg.call(&Map.to_list/1, 1)

# Dbg.local_call/1,2 is the same as Dbg.call/1,2 but for local calls
Dbg.local_call(&Map.to_list/1)

# Dbg.cancel/1,2 will cancel all call tracing for a specific pattern,
# similar too :dbg.ctp/2:
Dbg.cancel(&Map.to_list/1)

# Dbg.patterns/0 will return a map of the patterns with saved id's for keys,
# similar to :dbg.ltp/0:
Dbg.patterns()

# Dbg.reset/0 will cancel all tracing and is equivalent to :dbg.stop_clear/0
Dbg.reset()

# Dbg.node/1 will start tracing on another node, equivalent to :dbg.n/1:
Dbg.node(:"node@host")

# Dbg.nodes/0 will list all traced nodes, similar to :dbg.ln/1:
Dbg.nodes()

# Dbg.clear_node/1 will stop tracing on another node, equivalent to
#:dbg.cn/1:
Dbg.clear_node(:"node@host")

# Because Dbg is a wrapper for :dbg, all :dbg functions will work as normal,
# except that the trace messages will be formatted by Dbg instead of the
# default :dbg handler. The Dbg handler uses IEx.configuration/0 to format
# trace messages.
```
