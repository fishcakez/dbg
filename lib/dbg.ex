defmodule Dbg do

  @compile {:parse_transform, :ms_transform}

  @typep process :: pid | atom | { :global, term} | { atom, node } |
    { :via, module, term }
  @typep item :: :all | :new | :existing | process
  @typep flag :: :s | :send | :r | :receive | :m | :messages | :c | :call | :p |
  :procs | :sos | :setonspawn | :sofs | :setonfirstspawn | :sol | :setonlink |
  :sofl | :setonfirstlink | :all | :silent | :clear | :garbage_collection |
  :arity | :running | :return_to | :timestamp
  @typep option :: :return | :exception | :stack | :caller |
    { :silent, boolean } | { :enable | :disable, flag } |
    { :enable | :disable, pid, flag }
  @typep fun_call :: fun | module | { module, atom, arity } | { module, atom }
  @typep id :: nil | pos_integer | :c | :x | :cx
  @typep pattern :: fun | Dbg.MatchSpec.t | String.t | id | option | [option]

  @spec trace(item, flag | [flag]) :: map
  def trace(item, flag \\ :all)

  def trace(item, flag) when item in [:all, :new, :existing] or is_pid(item) do
    try do
      :dbg.p(item, flag)
    else
      {:ok, result} ->
        parse_result(result)
      {:error, reason} ->
        exit({reason, {__MODULE__, :trace, [item, flag]}})
    catch
      :exit, :dbg_server_crashed ->
        exit({:dbg_server_crashed, {__MODULE__, :trace, [item, flag]}})
    end
  end

  def trace(process, flag) do
    case whereis(process) do
      nil ->
        exit({:noproc, {__MODULE__, :trace, [process, flag]}})
      pid when is_pid(pid) ->
        try do
          :dbg.p(pid, flag)
        else
          {:ok, result} ->
            parse_result(result)
          {:error, reason} ->
            exit({reason, {__MODULE__, :trace, [process, flag]}})
        catch
          :exit, :dbg_server_crashed ->
            exit({:dbg_server_crashed, {__MODULE__, :trace, [process, flag]}})
        end
    end
  end

  @spec clear(item) :: map
  def clear(item \\ :all) do
    try do
      trace(item, :clear)
    catch
      :exit, {reason, {__MODULE__, :trace, _args}} ->
        exit({reason, {__MODULE__, :clear, [item]}})
    end
  end

  @spec node(node) :: :ok
  def node(node_name) do
    try do
      :dbg.n(node_name)
    else
      {:ok, _node_name} -> :ok
      {:error, reason} -> exit({reason, {__MODULE__, :node, [node_name]}})
    catch
      :exit, :dbg_server_crash ->
        exit({:dbg_server_crash, {__MODULE__, :node, [node_name]}})
    end
  end


  @spec nodes() :: [node]
  def nodes() do
    case req(:get_nodes) do
      {:ok, nodes} -> nodes
      {:error, reason} -> exit({reason, {__MODULE__, :nodes, []}})
    end
  end

  @spec clear_node(node) :: :ok
  def clear_node(node_name) do
    try do
      :dbg.cn(node_name)
    catch
      :exit, :dbg_server_crash ->
        exit({:dbg_server_crash, {__MODULE__, :clear_node, [node_name]}})
    end
  end

  @spec call(fun_call, pattern) :: map
  def call(target, pattern \\ nil) do
    try do
      apply_pattern(&:dbg.tp/2, target, pattern)
    else
      {:ok, result} ->
        parse_result(result)
      {:error, reason} ->
        exit({reason, {__MODULE__, :call, [target, pattern]}})
    catch
      :exit, :dbg_server_crash ->
        exit({:dbg_server_crash, {__MODULE__, :call, [target, pattern]}})
    end
  end

  @spec local_call(fun_call, pattern) :: map
  def local_call(target, pattern \\ nil) do
    try do
      apply_pattern(&:dbg.tpl/2, target, pattern)
    else
      {:ok, result} ->
        parse_result(result)
      {:error, reason} ->
        exit({reason, {__MODULE__, :local_call, [target, pattern]}})
    catch
      :exit, :dbg_server_crash ->
        exit({:dbg_server_crash,
          {__MODULE__, :local_call, [target, pattern]}})
    end
  end

  @spec cancel(fun_call) :: map
  def cancel(target) do
    try do
      apply_target(&:dbg.ctp/1, target)
    else
      {:ok, result} ->
        parse_result(result)
      {:error, reason} ->
        exit({reason, {__MODULE__, :cancel, [target]}})
    catch
      :exit, :dbg_server_crash ->
        exit({:dbg_server_crash, {__MODULE__, :cancel, [target]}})
    end
  end

  @spec patterns() :: map
  def patterns() do
    case req(:get_table) do
      {:ok, {:ok, tid}} ->
        patterns(tid)
      {:error, reason} ->
        exit({reason, {__MODULE__, :patterns, []}})
    end
  end

  @spec reset() :: :ok
  def reset() do
    flush()
    Dbg.Watcher.reset()
  end

  @doc false
  @spec flush() :: :ok
  def flush() do
    # Abuse code that (hopefully) exists on all nodes to ensure traces
    # delivered. This will fail on all nodes but only after checking traces
    # delivered
    nodes = Dbg.nodes()
    _ = :rpc.multicall(nodes, :dbg, :deliver_and_flush, [:undefined])
    # flush the local file trace port (if it exists).
    try do
      :dbg.flush_trace_port()
    else
      _ ->
        :ok
    catch
      :exit, _ ->
        :ok
    end
  end

  @spec inspect_file(IO.device, Path) :: :ok | {:error, any}
  def inspect_file(device \\ :standard_io, file) do
    erl_file = IO.chardata_to_string(file) |> String.to_char_list()
    # race condition here, pid could close before monitor.
    pid = :dbg.trace_client(:file, erl_file, Dbg.Handler.spec(device))
    ref = Process.monitor(pid)
    receive do
      {:DOWN, ^ref, _, _, :normal} ->
        :ok
      {:DOWN, ^ref, _, _, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def transform_ms(match_spec) do
    Enum.map(match_spec, &map_ms/1)
  end

  ## internal

  defp whereis(pid) when is_pid(pid), do: pid
  defp whereis(name) when is_atom(name), do: Process.whereis(name)

  defp whereis({ name, node_name })
      when is_atom(name) and node_name === node() do
    Process.whereis(name)
  end

  defp whereis({ :global, name }) do
    case :global.whereis_name(name) do
      :undefined ->
        nil
      pid ->
        pid
    end
  end

  defp whereis({ name, node_name }) when is_atom(name) and is_atom(node_name) do
    case :rpc.call(node_name, :erlang, :whereis, [name]) do
      pid when is_pid(pid) ->
        pid
      # :undefined or bad rpc
      _other ->
        nil
    end
  end

  defp whereis({ :via, mod, name }) when is_atom(name) do
    case mod.whereis_name(name) do
      :undefined ->
        nil
      pid ->
        pid
    end
  end

  defp req(request) do
    case Process.whereis(:dbg) do
      nil ->
        {:error, :noproc}
      pid ->
        req(pid, request)
    end
  end

  defp req(pid, request) do
    ref = Process.monitor(pid)
    send(pid, {self(), request})
    receive do
      {:DOWN, ^ref, _, _, _} ->
        # copy behaviour of other
        {:error, :dbg_server_crash}
      {:dbg, response} ->
        {:ok, response}
    end
  end

  defp ext_fun_info(ext_fun) do
    { :module, mod } = :erlang.fun_info(ext_fun, :module)
    { :name, name } = :erlang.fun_info(ext_fun, :name)
    { :arity, arity } = :erlang.fun_info(ext_fun, :arity)
    { mod, name, arity}
  end

  defp apply_pattern(fun, target, pattern) do
    fun.(get_target(target), get_pattern(pattern))
  end

  defp apply_target(fun, target) do
    fun.(get_target(target))
  end

  defp get_target({ _mod, _fun, _arity } = target), do: target
  defp get_target({ mod, fun }), do: { mod, fun, :_ }
  defp get_target(mod) when is_atom(mod), do: { mod, :_, :_ }

  defp get_target(ext_fun) when is_function(ext_fun) do
    case :erlang.fun_info(ext_fun, :type) do
      {:type, :external} ->
        ext_fun_info(ext_fun)
        _other ->
          raise ArgumentError, "#{inspect(ext_fun)} is not an external fun"
    end
  end

  defp get_pattern(id) when is_integer(id) or id in [:c, :x, :cx], do: id

  defp get_pattern(nil), do: get_pattern([])

  defp get_pattern(option) when is_atom(option) or is_tuple(option) do
    get_pattern([option])
  end

  defp get_pattern(options)
      when is_atom(hd(options)) or
        elem(hd(options), 0) in [ :silent, :enable, :disable] do
    [{:_, [], transform_options(options)}]
  end

  defp get_pattern(string) when is_binary(string) do
    {[match_spec], _ } = Dbg.MatchSpec.eval_string(string)
    match_spec
  end

  defp get_pattern(fun) when is_function(fun, 1) do
    Dbg.MatchSpec.eval_fun(fun)
  end

  defp get_pattern(match_spec) when is_list(match_spec) do
    transform_ms(match_spec)
  end

  defp map_ms({ pat, guard, [options] }) when is_list(options) do
    { pat, guard, transform_options(options) }
  end

  defp map_ms({ pat, guard, options }) do
    { pat, guard, transform_options(options) }
  end

  defp transform_options(options) do
    Enum.map(options, &transform_option/1)
  end

  defp transform_option(:return), do: { :return_trace }
  defp transform_option(:stack), do: { :message, { :process_dump } }
  defp transform_option(:caller), do: { :message, { :caller } }
  defp transform_option(:exception), do: { :exception_trace }
  defp transform_option({ :silent, flag }), do: { :silent, flag }
  defp transform_option({ :enable, flag }), do: { :enable_trace, flag }
  defp transform_option({ :disable, flag }), do: { :disable_trace, flag }

  defp transform_option({ :enable, pid, flag }) do
    { :enable_trace, pid, flag }
  end

  defp transform_option({ :disable, pid, flag }) do
    { :disable_trace, pid, flag }
  end

  defp transform_option(option) do
    raise ArgumentError, message: "invalid option #{inspect(option)}"
  end

  defp parse_result(result) do
    {id, good, bad} = Enum.reduce(result, {nil, %{}, %{}}, &parse_result/2)
    result = %{counts: good, errors: bad}
    if id === nil, do: result, else: Map.put(result, :saved, id)
  end

  defp parse_result({:matched, node_name, count}, {id, good, bad}) do
    {id, Map.put(good, node_name, count), bad}
  end

  defp parse_result({:matched, node_name, 0, error}, {id, good, bad}) do
    {id, good, Map.put(bad, node_name, error)}
  end

  defp parse_result({:saved, id}, {_id, good, bad}) do
    {id, good, bad}
  end

  defp patterns(tid) do
    ms = :ets.fun2ms(fn({id, bin}) when is_integer(id) or id in [:x, :c, :cx] ->
      {id, bin}
    end)
    :ets.select(tid, ms)
      |> Enum.reduce(%{}, &patterns/2)
  end

  defp patterns({id, binary}, map) do
    try do
      Map.put(map, id, (:erlang.binary_to_term(binary) |> untransform_ms()))
    catch
      # failed to convert ms body (added using :dbg), ignore.
      :error, _ ->
        map
    end
  end

  defp untransform_ms(ms) do
    for {head, conds, body} <- ms do
      {head, conds, Enum.map(body, &untransform_option/1)}
    end
  end

  defp untransform_option({ :return_trace }), do: :return
  defp untransform_option({ :message, { :return_trace } }), do: :return
  defp untransform_option({ :message, { :process_dump } }), do: :stack
  defp untransform_option({ :message, { :caller } }), do: :caller
  defp untransform_option({ :exception_trace }), do: :exception
  defp untransform_option({ :message, { :exception_trace } }), do: :exception
  defp untransform_option({ :silent, flag }), do: { :silent, flag }
  defp untransform_option({ :enable_trace, flag }), do: { :enable, flag }
  defp untransform_option({ :disable_trace, flag }), do: { :enable, flag }

  defp untransform_option({ :enable_trace, pid, flag }) do
    { :enable, pid, flag }
  end

  defp untransform_option({ :disable_trace, pid, flag }) do
    { :disable, pid, flag }
  end
end
