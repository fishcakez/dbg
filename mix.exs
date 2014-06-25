defmodule Dbg.Mixfile do
  use Mix.Project

  def project do
    [app: :dbg,
     version: "0.14.1",
     elixir: "~> 0.14.0",
     name: "Dbg",
     source_url: "https://github.com/fishcakez/dbg",
     hompage_url: "https://github.com/fishcakez/dbg",
     deps: deps]
  end

  def application do
    [ applications: [:iex, :runtime_tools],
      mod: { Dbg.App, [] } ]
  end

  defp deps do
    [{:ex_doc, github: "elixir-lang/ex_doc", only: [:docs]}]
  end
end
