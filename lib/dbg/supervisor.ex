defmodule Dbg.Supervisor do

  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, nil, [name: __MODULE__])
  end

  def init(_) do
    children = [worker(Dbg.Watcher, [])]
    supervise(children, strategy: :one_for_one)
  end

end
