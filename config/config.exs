use Mix.Config

config :txbox,
  repo: Txbox.Test.Repo,
  ecto_repos: [Txbox.Test.Repo]

config :txbox, Txbox.Test.Repo,
  database: "txbox_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "priv/tmp/txbox_test"

config :logger, level: :warn

config :tesla, adapter: Tesla.Mock
