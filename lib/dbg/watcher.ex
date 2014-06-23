defmodule Dbg.Watcher do

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__])
  end

  def init(_) do
    # trap so can stop :dbg in terminate
    Process.flag(:trap_exit, true)
    case start_tracer() do
      { :ok, pid } ->
        { :ok, Process.monitor(pid) }
      # :dbg already running, wait for it to close.
      { :error, :already_started } ->
        { :ok, Process.monitor(:dbg) }
      { :error, reason } ->
        { :stop, reason}
    end
  end

  # :done means tracing finished but Dbg.Handler could have crashed. If so a
  # warning would be printed.
  def handle_info({ :DOWN, ref, _, _, :done }, ref) do
    { :stop, :shutdown, nil }
  end

  def handle_info({ :DOWN, ref, _, _, reason }, ref) do
    { :stop, reason, nil }
  end

  def handle_info(other, ref) do
   :error_logger.error_msg('~ts received unexpected ~ts~n',
     [inspect(self()), inspect(other)])
   { :noreply, ref }
  end

  def terminate(_reason, nil), do: :ok
  def terminate(_reason, _ref), do: :ok = :dbg.stop_clear()

  ## internal

  defp start_tracer() do
    case Application.get_env(:dbg, :device, :user) do
      {:file, file} ->
        erl_file = IO.chardata_to_string(file) |> String.to_char_list()
        :dbg.tracer(:port, :dbg.trace_port(:file, erl_file))
      device ->
        :dbg.tracer(:process, Dbg.Handler.spec(device))
    end
  end

end
