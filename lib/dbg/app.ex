defmodule Dbg.App do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Dbg.Supervisor.start_link()
  end

end
