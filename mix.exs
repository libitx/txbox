defmodule Bitbox.MixProject do
  use Mix.Project

  def project do
    [
      app: :bitbox,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Bitbox.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.4"},
      {:ecto_sql, "~> 3.4"},
      {:jason, "~> 1.2"},
      {:gen_stage, "~> 1.0"},
      {:manic, "~> 0.0.3"},
      {:postgrex, "~> 0.15", optional: true},
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      test: [
        "ecto.drop --quiet",
        "ecto.create --quiet",
        "bitbox.gen.migration",
        "ecto.migrate",
        "test"
      ]
    ]
  end
end
