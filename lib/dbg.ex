defmodule Dbg do

  @typep process :: pid | atom | { :global, term} | { atom, node } |
    { :via, module, term }
  @typep item :: :all | :new | :existing | process
  @typep flag :: :s | :send | :r | :receive | :m | :messages | :c | :call | :p |
  :procs | :sos | :setonspawn | :sofs | :setonfirstspawn | :sol | :setonlink |
  :sofl | :setonfirstlink | :all | :silent | :clear
  @typep option :: :return | :exception | :stack | :caller |
    { :silent, boolean } | { :enable | :disable, flag } |
    { :enable | :disable, pid, flag }
  @typep fun_call :: fun | module | { module, atom, arity } | { module, atom }
  @typep pattern :: fun | Dbg.MatchSpec.t | String.t | pos_integer |
    option | [option]

  @spec trace(item, flag | [flag]) ::
    { :ok, [{ :matched, node, non_neg_integer } |
        { :matched, node, 0, any }] } |
    { :error, any }
  def trace(item, flag \\ :m)

  def trace(builtin, flag) when builtin in [:all, :new, :existing] do
    :dbg.p(builtin, flag)
  end

  def trace(pid, flag) when is_pid(pid) do
    :dbg.p(pid, flag)
  end

  def trace(process, flag) do
    case whereis(process) do
      nil ->
        raise ArgumentError,
          message: "no process associated with #{inspect(process)}"
      pid when is_pid(pid) ->
        :dbg.p(pid, flag)
    end
  end

  @spec clear(item) ::
    { :ok, [{ :matched, node, non_neg_integer } |
        { :matched, node, 0, any }] } |
    { :error, any }
  def clear(process \\ :all) do
    trace(process, :clear)
  end

  @spec node(node) :: { :ok, node } | { :error, any }
  def node(node_name), do: :dbg.n(node_name)

  @spec nodes() :: [node]
  def nodes(), do: :dbg.ln()

  @spec clear_node(node) :: :ok
  def clear_node(node_name), do: :dbg.cn(node_name)

  @spec call(fun_call, pattern) ::
    { :ok, [{ :matched, node, non_neg_integer } |
        { :matched, node, 0, any } | { :saved, pos_integer }] } |
    { :error, any }
  def call(target, pattern \\ []) do
    apply_pattern(&:dbg.tp/2, target, pattern)
  end

  @spec local_call(fun_call, pattern) ::
    { :ok, [{ :matched, node, non_neg_integer } |
        { :matched, node, 0, any } | { :saved, pos_integer }] } |
    { :error, any }
  def local_call(target, pattern \\ []) do
    apply_pattern(&:dbg.tpl/2, target, pattern)
  end

  @spec cancel(fun_call, pattern) ::
    { :ok, [{ :matched, non_neg_integer }] } | { :error, any }
  def cancel(target, pattern \\ []) do
    apply_pattern(&:dbg.ctp/2, target, pattern)
  end

  @spec reset() :: :ok
  defdelegate reset(), to: :dbg, as: :stop_clear

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

  defp ext_fun_info(ext_fun) do
    { :module, mod } = :erlang.fun_info(ext_fun, :module)
    { :name, name } = :erlang.fun_info(ext_fun, :name)
    { :arity, arity } = :erlang.fun_info(ext_fun, :arity)
    { mod, name, arity}
  end

  defp apply_pattern(fun, target, pattern) do
    fun.(get_target(target), get_pattern(pattern))
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


  defp get_pattern(id) when is_integer(id), do: id

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
  defp transform_option(:caller), do: { :caller }
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

end
