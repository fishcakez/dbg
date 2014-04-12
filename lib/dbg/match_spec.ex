defmodule Dbg.MatchSpec do

  @type t :: [{atom | list, list, [Dbg.option] }]

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
        Dbg.transform_ms(match_spec)
    catch
      :exit, { :dbg, :fun2ms, _ } ->
        raise ArgumentError, message: "#{inspect(fun)} is not an eval fun"
    end
  end

  def eval_enum(enum), do: Enum.map(enum, &eval_fun/1)

  ## internal

  defp eval_with(arg, binding, opts, fun) do
    case fun.(arg, binding, opts) do
      { fun, bindings } when is_function(fun, 1) ->
        { [eval_fun(fun)], bindings }
      { enum, bindings } ->
        { eval_enum(enum), bindings }
    end
  end

end
