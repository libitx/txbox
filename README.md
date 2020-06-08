# Txbox

Txbox is an Elixir implementation of the [TXT Semantic Bitcoin Storage](https://txt.network/) schema. Txbox lets you store Bitcoin transactions in your application's database with searchable and filterable semantic metadata.

* 100% compatible with TXT, with near identical schema design and API for searching and filtering.
* As Txbox is built on Ecto, you query your own database rather than a containerized HTTP process.
* Like TXT, Txbox auto-syncs with the [Miner API](https://github.com/bitcoin-sv/merchantapi-reference) of your choice, and caches signed responses.
* Unlike TXT, no web UI or HTTP API is exposed. Txbox is purely a database schema with query functions - the rest is up to you.
* Seamlessly import and export from other TXT-compatible platforms (soon... &tm;).

## Installation

The package can be installed by adding `tx_box` to your list of dependencies in mix.exs.


```elixir
def deps do
  [
    {:txbox, "~> 0.1"}
  ]
end
```

Once installed, run the following tasks to generate and run the required database migrations.

```console
mix txbox.gen.migration
mix ecto.migrate
```

Finally, add the following to your project's `config/config.exs`:

TODO