defmodule Dbg.Watcher do
  @moduledoc false

  use GenServer

  defstruct [dbg_ref: nil, tracer_ref: nil, tracer: nil]

  def start_link() do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__])
  end

  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  def init(_) do
    # trap so can stop :dbg in terminate
    Process.flag(:trap_exit, true)
    case start_tracer() do
      { :ok, _state } = result ->
        result
      # :dbg already running, wait for it to close.
      { :error, :already_started } ->
        { :ok, %Dbg.Watcher{ dbg_ref: Process.monitor(:dbg) } }
      { :error, reason } ->
        { :stop, reason}
    end
  end

  def handle_call(:reset, _from, state) do
    {:ok, state} = restart_tracer(state)
    { :reply, :ok, state }
  end

  # :done means tracing finished but Dbg.Handler could have crashed. If so a
  # warning would be printed. Don't restart, probably a Dbg.reset call.
  def handle_info({ :DOWN, dbg_ref, _, _, :done },
    %{ dbg_ref: dbg_ref } = state) do
    { :ok, state } = restart_tracer(%{ state | dbg_ref: nil })
    { :noreply, state }
  end

  def handle_info({ :DOWN, dbg_ref, _, _, reason },
      %{ dbg_ref: dbg_ref } = state) do
    { :stop, reason, %{ state | dbg_ref: nil } }
  end

  def handle_info({ :DOWN, tracer_ref, _, _, :normal },
      %{ tracer_ref: tracer_ref } = state) do
    { :ok, state } = restart_tracer(%{ state | tracer_ref: nil, tracer: nil })
    { :noreply, state }
  end

  def handle_info({ :DOWN, tracer_ref, _, _, reason },
      %{ tracer_ref: tracer_ref } = state) do
    { :stop, reason, %{ state | tracer_ref: nil, tracer: nil } }
  end

  def handle_info(other, state) do
   :error_logger.error_msg('~ts received unexpected ~ts~n',
     [inspect(self()), inspect(other)])
   { :noreply, state }
  end

  def terminate(_reason, state), do: stop_tracer(state)

  ## internal

  defp start_tracer() do
    case start_tracer(Application.get_env(:dbg, :device, :user)) do
      { :ok, _struct } = result ->
        result
      { :error, :already_started } ->
        {:ok, %__MODULE__{ dbg_ref: Process.monitor(:dbg) } }
      { :error, _reason } = error ->
        error
    end
  end

  def start_tracer({:file, file}) do
    erl_file = IO.chardata_to_string(file) |> String.to_char_list()
    case :dbg.tracer(:port, :dbg.trace_port(:file, erl_file)) do
      { :ok, dbg } ->
        { :ok, %__MODULE__{ dbg_ref: Process.monitor(dbg) } }
      error ->
        error
    end
  end

  def start_tracer(device) do
    case :dbg.tracer(:process, Dbg.Handler.spec(device)) do
      { :ok, dbg } ->
        { :ok, tracer } = :dbg.get_tracer()
        dbg_ref = Process.monitor(dbg)
        tracer_ref = Process.monitor(tracer)
        { :ok, %__MODULE__{ dbg_ref: dbg_ref, tracer_ref: tracer_ref,
            tracer: tracer } }
      { :error, _reason } = error ->
        error
    end
  end

  defp restart_tracer(state) do
    :ok = stop_tracer(state)
    start_tracer()
  end

  defp stop_tracer(%{ dbg_ref: nil, tracer_ref: nil, tracer: nil }) do
    :ok
  end

  defp stop_tracer(%{ dbg_ref: dbg_ref} = state) when is_reference(dbg_ref) do
    Process.demonitor(dbg_ref, [:flush])
    try do
      Dbg.clear(:all)
      :dbg.stop_clear()
    else
      :ok ->
        stop_tracer(%__MODULE__{ state | dbg_ref: nil })
    catch
      :exit, _ ->
        stop_tracer(%__MODULE__{ state | dbg_ref: nil })
    end
  end

  defp stop_tracer(%{ tracer_ref: tracer_ref, tracer: tracer } = state) do
    # tracer might ignore :EXIT from :dbg if it receives it while reading
    # trace messages. In that case we will kill the tracer if it doesn't exit
    # in time. Waiting for the :DOWN will also block a reset call while IO
    # gets written, though there are no guarantees all will get written before
    # killed.
    receive do
      { :DOWN, ^tracer_ref, _, _, _reason } ->
        stop_tracer(%__MODULE__{ state | tracer_ref: nil, tracer: nil })
    after
      3000 ->
        Process.demonitor(tracer_ref, [:flush])
        Process.exit(tracer, :kill)
        stop_tracer(%__MODULE__{ state | tracer_ref: nil, tracer: nil })
    end
  end

end
