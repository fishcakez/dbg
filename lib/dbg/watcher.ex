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
      { :error, reason } ->
        { :stop, reason }
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
    Application.get_env(:dbg, :device, :user)
      |> Dbg.Handler.start()
  end

end
