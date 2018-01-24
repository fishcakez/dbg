defmodule Dbg.Mixfile do
  use Mix.Project

  @version "1.0.1"

  def project do
    [app: :dbg,
     version: @version,
     elixir: "~> 1.0",
     name: "Dbg",
     hompage_url: "https://github.com/fishcakez/dbg",
     description: description(),
     package: package(),
     docs: [
       source_ref: "v#{@version}",
       source_url: "https://github.com/fishcakez/dbg",
       main: Dbg,
     ],
     deps: deps()]
  end

  def application do
    [ applications: [:iex, :runtime_tools],
      mod: { Dbg.App, [] } ]
  end

  defp deps do
    [
      {:ex_doc, "0.11.1", only: [:dev]},
      {:earmark, "~> 0.1", only: [:dev]}
    ]
  end

  defp description do
    """
    Distributed tracing
    """
  end

  defp package do
    [files: ["lib", "mix.exs", "README.md", "LICENSE"],
      contributors: ["James Fish"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/fishcakez/dbg"}]
  end

end
