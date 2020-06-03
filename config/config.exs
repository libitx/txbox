use Mix.Config

config :bitbox,
  repo: Bitbox.Test.Repo,
  ecto_repos: [Bitbox.Test.Repo]

config :bitbox, Bitbox.Test.Repo,
  database: "bitbox_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "priv/tmp/bitbox_test"

config :logger, level: :warn
