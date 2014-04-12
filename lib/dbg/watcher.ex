defmodule Dbg.Watcher do

  use GenServer.Behaviour

  def start_link() do
    :gen_server.start_link({ :local, __MODULE__ }, __MODULE__, nil, [])
  end

  def init(_) do
    # trap so can stop :dbg in terminate
    Process.flag(:trap_exit, true)
    devices = :application.get_env(:dbg, :devices, [:stdio])
    opts = :application.get_env(:dbg, :options, default_opts())
    case Dbg.Handler.start(devices, opts) do
      { :ok, pid } ->
        { :ok, Process.monitor(pid) }
      { :error, reason } ->
        { :stop, reason }
    end
  end

  def handle_info({ :DOWN, ref, _, _, reason}, ref) do
    { :stop, { :shutdown, reason }, nil }
  end

  def handle_info(other, ref) do
   :error_logger.error_msg('~ts received unexpected ~ts~n',
     [inspect(self()), inspect(other)])
   { :noreply, ref }
  end

  def terminate(_reason, _ref), do: :dbg.stop_clear()

  ## internal
  defp default_opts() do
    if ( IEx.Options.get(:colors) |> Keyword.get(:enabled, false) ) do
      [:colors]
    else
      []
    end
  catch
    :error, _ ->
      []
  end

end
