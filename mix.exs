defmodule Dbg.Mixfile do
  use Mix.Project

  def project do
    [app: :dbg,
     version: "0.14.3",
     elixir: "~> 0.15.0 or ~> 1.0.0 or ~> 1.1.0-dev",
     name: "Dbg",
     source_url: "https://github.com/fishcakez/dbg",
     hompage_url: "https://github.com/fishcakez/dbg",
     description: description(),
     package: package(),
     deps: deps]
  end

  def application do
    [ applications: [:iex, :runtime_tools],
      mod: { Dbg.App, [] } ]
  end

  defp deps do
    [{:ex_doc, ">= 0.5.2", only: [:docs]}]
  end

  defp description do
    """
    Distributed tracing
    """
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md"],
      contributors: ["James Fish"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/fishcakez/dbg"}]
  end

end
