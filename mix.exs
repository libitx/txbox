defmodule Txbox.MixProject do
  use Mix.Project

  def project do
    [
      app: :txbox,
      version: "0.1.0-beta.1",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      name: "Txbox",
      description: "TODO",
      source_url: "https://github.com/libitx/txbox",
      docs: [
        main: "Txbox",
        groups_for_functions: [
          "Expressions": & &1[:group] == :expression,
          "Queries": & &1[:group] == :query
        ],
        groups_for_modules: [
          "Schema": [
            Txbox.Transactions.Tx,
            Txbox.Transactions.Meta,
            Txbox.Transactions.Status
          ]
        ]
      ],
      package: [
        name: "manic",
        files: ~w(lib .formatter.exs mix.exs priv README.md LICENSE.md),
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/libitx/txbox"
        }
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.4"},
      {:ecto_sql, "~> 3.4"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:jason, "~> 1.2"},
      {:gen_stage, "~> 1.0"},
      {:manic, "~> 0.0.3"},
      {:postgrex, "~> 0.15", optional: true},
      {:qex, "~> 0.5"}
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
        "txbox.gen.migration",
        "ecto.migrate",
        "test"
      ]
    ]
  end
end
