defmodule Dbg.Supervisor do

  use Supervisor.Behaviour

  def start_link(), do: :supervisor.start_link(__MODULE__, nil)

  def init(_) do
    children = [worker(Dbg.Watcher, [])]
    supervise(children, strategy: :one_for_one)
  end

end
