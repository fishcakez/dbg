defmodule Dbg.App do
  @moduledoc false

  use Application.Behaviour

  def start(_type, _args) do
    Dbg.Supervisor.start_link()
  end

end
