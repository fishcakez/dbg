defmodule Dbg.MatchSpec do

  @type t :: [{atom | list, list, [Dbg.option] }]

  @all_native_flags [:send, :receive, :procs, :call, :silent, :return_to,
    :running, :garbage_collection, :timestamp, :arity, :set_on_spawn,
    :set_on_first_spawn, :set_on_link, :set_on_first_link]

  def eval_quoted(quoted, binding \\ [], opts \\ []) do
    eval_with(quoted, binding, opts, &Code.eval_quoted/3)
  end

  def eval_string(string, binding \\ [], opts \\ []) do
    eval_with(string, binding, opts, &Code.eval_string/3)
  end

  def eval_fun(fun) do
    try do
      :dbg.fun2ms(fun)
    else
      { :error, reason } ->
        raise ArgumentError,
          message: "#{inspect(fun)} could not be transformed: " <>
            "#{inspect(reason)}"
      match_spec ->
        transform(match_spec)
    catch
      :exit, { :dbg, :fun2ms, _ } ->
        raise ArgumentError, message: "#{inspect(fun)} is not an eval fun"
    end
  end

  def eval_enum(enum), do: Enum.map(enum, &eval_fun/1)

  def transform(match_spec) do
    Enum.map(match_spec, &transform_ms/1)
  end

  def untransform(ms) do
    for {head, conds, body} <- ms do
      {head, conds, Enum.map(body, &untransform_option/1)}
    end
  end

  def transform_flags(flags) when is_list(flags) do
    Enum.flat_map(flags, &transform_flag/1)
  end

  def transform_flags(flag) when is_atom(flag) do
    transform_flag(flag)
  end

  ## internal

  defp eval_with(arg, binding, opts, fun) do
    case fun.(arg, binding, opts) do
      { fun, bindings } when is_function(fun, 1) ->
        { [eval_fun(fun)], bindings }
      { enum, bindings } ->
        { eval_enum(enum), bindings }
    end
  end

  defp transform_ms({ pat, guard, [options] }) when is_list(options) do
    { pat, guard, transform_options(options) }
  end

  defp transform_ms({ pat, guard, options }) do
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
  defp transform_option(:clear), do: {:trace, @all_native_flags, []}
  defp transform_option({:clear, pid}), do: {:trace, pid, @all_native_flags, []}
  defp transform_option({ :trace, on }), do: { :trace, [], transform_flags(on) }

  defp transform_option({ :trace, pid, on }) do
    { :trace, pid, [], transform_flags(on) }
  end

  defp transform_option(option) do
    raise ArgumentError, message: "invalid option: " <> inspect(option)
  end

  defp transform_flag(native_flag)
      when native_flag in @all_native_flags do
    [native_flag]
  end

  defp transform_flag(:all), do: @all_native_flags -- [:silent]
  defp transform_flag(:s), do: [:send]
  defp transform_flag(:r), do: [:r]
  defp transform_flag(:m), do: [:send, :receive]
  defp transform_flag(:messages), do: [:send, :receive]
  defp transform_flag(:c), do: [:call]
  defp transform_flag(:p), do: [:procs]
  defp transform_flag(:sos), do: [:set_on_spawn]
  defp transform_flag(:sofs), do: [:set_on_first_spawn]
  defp transform_flag(:sol), do: [:set_on_link]
  defp transform_flag(:sofl), do: [:set_on_first_link]

  defp transform_flag(bad_flag) do
    raise ArgumentError, [message: "invalid flag: " <> inspect(bad_flag)]
  end

  defp untransform_option({ :return_trace }), do: :return
  defp untransform_option({ :message, { :return_trace } }), do: :return
  defp untransform_option({ :message, { :process_dump } }), do: :stack
  defp untransform_option({ :message, { :caller } }), do: :caller
  defp untransform_option({ :exception_trace }), do: :exception
  defp untransform_option({ :message, { :exception_trace } }), do: :exception
  defp untransform_option({ :silent, flag }), do: { :silent, flag }
  defp untransform_option({ :trace, [], on }), do: { :trace, on }
  defp untransform_option({ :trace, pid, [], on }), do: { :trace, pid, on }
  defp untransform_option({ :trace, @all_native_flags, [] }), do: :clear
  defp untransform_option({ :trace, pid, @all_native_flags, [] }) do
    { :clear, pid }
  end

end
