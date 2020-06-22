# Txbox

![Elixir Bitcoin Tx storage schema](https://github.com/libitx/txbox/raw/master/media/poster.png)

![Hex.pm](https://img.shields.io/hexpm/v/txbox?color=informational)
![MIT License](https://img.shields.io/github/license/libitx/txbox?color=informational)
![GitHub Workflow Status](https://img.shields.io/github/workflow/status/libitx/txbox/Elixir%20CI)

Txbox is a Bitcoin transaction storage schema, based on [TXT](https://txt.network/). Txbox lets you store Bitcoin transactions in your application's database with searchable and filterable semantic metadata.

* 100% compatible with TXT, with near identical schema design and API for searching and filtering.
* As Txbox is built on Ecto, you query your own database rather than a containerized HTTP process.
* Create associations with any other data from your app's domain.
* Like TXT, Txbox auto-syncs with the [Miner API](https://github.com/bitcoin-sv/merchantapi-reference) of your choice, and caches signed responses.
* Unlike TXT, no web UI or HTTP API is exposed. Txbox is purely a database schema with query functions - the rest is up to you.
* Coming soon (™) - Seamlessly import and export from other TXT-compatible platforms.

## Installation

The package can be installed by adding `txbox` to your list of dependencies in `mix.exs`.


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

Update your application's configuration, making sure Txbox knows which Repo to use.

```elixir
# config/config.exs
config :txbox, repo: MyApp.Repo
```      

Finally, add `Txbox` to your application's supervision tree.

```elixir
children = [
  {Txbox, [
    # Manic miner configuration (required)
    miner: {:taal, headers: [{"token", "MYTOKEN"}]},
    # Number of times to attempt polling the miner (default is 20)
    max_retries: 20,
    # Number of seconds to wait before re-polling the miner (default is 300 - 5 minutes)
    retry_after: 300
  ]}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

## Usage

Once up an running, using Txbox is simple. The `Txbox` modules provides three functions for creating and finding transactions: `set/2`, `get/2`, and `all/2`.

To add a transaction to Txbox, the minimum required is to give a `txid`.

```elixir
iex> Txbox.set(%{
...>   txid: "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110"
...> })
{:ok, %Tx{}}
```

Once a transaction is added, Txbox automatically syncs with the Miner API of your choice, updating the transaction's status until it is confirmed in a block.

When a channel name is ommitted, transactions are added to the `default_channel/0` (`"txbox"`), but by specifiying a channel name as the first argument, that transaction will be added to that channel. You can provide additional metadata about the transaction, as well as attach the raw transaction binary.

```elixir
iex> Txbox.set("photos", %{
...>   txid: "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110",
...>   rawtx: <<...>>,
...>   tags: ["hubble", "universe"],
...>   meta: %{
...>     title: "Hubble Ultra-Deep Field"
...>   },
...>   data: %{
...>     bitfs: "https://x.bitfs.network/6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110.out.0.3"
...>   }
...> })
{:ok, %Tx{}}
```

The transaction can be retrieved by the `txid` too.

```elixir
iex> Txbox.get("6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110")
{:ok, %Tx{}}
```

As before, omitting the channel scopes the query to the `default_channel/0` (`"txbox"`). Alterntively you can pass the channel name as the first argument, or use `"_"` which is the TXT syntax for global scope.

```elixir
iex> Txbox.get("_", "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110")
{:ok, %Tx{}}
```

A list of transactions can be returned using `all/2`. The second parameter must be a `t:map/0` of query parameters to filter and search by.

```elixir
iex> Txbox.all("photos", %{
...>   from: 636400,
...>   tagged: "hubble",
...>   limit: 5
...> })
{:ok, [%Tx{}, ...]}
```

A full text search can be made by using the `:search` filter parameter.

```elixir
iex> Txbox.all("_", %{
...>   search: "hubble deep field"
...> })
{:ok, [%Tx{}, ...]}
```

### Filtering and searching

Txbox adopts the same syntax and query modifiers [used by TXT](https://txt.network/#/?id=c-queries). Txbox automatically normalizes the query map, so keys can be specifiied either as atoms or strings. Here are a few examples:

* `:search` - Full text search made on trasactions' tags and meta data
  * `%{search: "hubble deep field"}`
* `:tagged` - Filter transactions by the given tag or tags
  * `%{tagged: "photos"}` - all transactions tagged with "photos"
  * `%{tagged: ["space", "hubble"]}` - all transactions tagged with *both* "space" and "hubble"
  * `%{tagged: "space, hubble"}` - as above, but given as a comma seperated string
* `:from` - The block height from which to filter transactions by
  * `%{from: 636400}` - all transactions from and including block 636400
* `:to` - The block height to which to filter transactions by
  * `%{to: 636800}` - all transactions upto and including block 636800
  * `%{from: 636400, to: 636800}` - all transactions in the range 636400 to 636800
* `:at` - The block height at which to filter transactions by exactly
  * `%{at: 636500}` - all transactions at block 636500
  * `%{at: "null"}` - all transactions without a block height (unconfirmed)
  * `%{at: "!null"}` - all transactions with any block height (confirmed)
* `:order` - The attribute to sort transactions by
  * `%{order: "i"}` - sort by block height in ascending order
  * `%{order: "-i"}` - sort by block height in descending order
  * `%{order: "created_at"}` - sort by insertion time in ascending order
  * `%{order: "-created_at"}` - sort by insertion time in descending order
* `:limit` - The maximum number of transactions to return
* `:offset` - The start offset from which to return transactions (for pagination)

## License

[MIT License](https://github.com/libitx/manic/blob/master/LICENSE.md).

© Copyright 2020 libitx.