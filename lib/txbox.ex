defmodule Txbox do
  @moduledoc """
  ![Elixir Bitcoin Tx storage schema](https://github.com/libitx/txbox/raw/master/media/poster.png)

  ![License](https://img.shields.io/github/license/libitx/txbox?color=informational)

  Txbox is a Bitcoin transaction storage schema. It lets you store Bitcoin
  transactions in your application's database with searchable and filterable
  semantic metadata. Txbox is inspired by [TXT](https://txt.network/) but
  adapted to slot into an Elixir developers toolset.

  * Built on Ecto! Store Bitcoin Transactions in your database and define associations with any other data from your app's domain.
  * Built in queue for pushing signed transactions to the Bitcoin network via the [Miner API](https://github.com/bitcoin-sv/merchantapi-reference).
  * Auto-syncs with the [Miner API](https://github.com/bitcoin-sv/merchantapi-reference) of your choice, and caches signed responses.
  * Aims to be compatible with TXT, with similar schema design and API for searching and filtering.
  * Unlike TXT, no web UI or HTTP API is exposed. Txbox is purely a database schema with query functions - the rest is up to you.
  * Coming soon (™) - Seamlessly import and export from other TXT-compatible platforms.

  ## Installation

  The package can be installed by adding `txbox` to your list of dependencies in
  `mix.exs`.

      def deps do
        [
          {:txbox, "~> 0.2"}
        ]
      end

  Once installed, run the following tasks to generate and run the required
  database migrations.

  ```console
  mix txbox.gen.migrations
  mix ecto.migrate
  ```

  Update your application's configuration, making sure Txbox knows which Repo to
  use.

      # config/config.exs
      config :txbox, repo: MyApp.Repo

  Finally, add `Txbox` to your application's supervision tree.

      children = [
        {Txbox, [
          # Manic miner configuration (defaults to :taal)
          miner: {:taal, headers: [{"token", "MYTOKEN"}]},
          # Maximum number of times to attempt polling the miner (default is 20)
          max_retries: 20,
          # Interval (in seconds) between each mAPI request (default is 300 - 5 minutes)
          retry_after: 300
        ]}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)

  ## Upgrading

  If upgrading from a previous version of `txbox`, make sure to run the migrations
  task to check if any new migrations are required.

  ```console
  mix txbox.gen.migrations
  # If needed
  mix ecto.migrate
  ```

  ## Usage

  Once up an running, using Txbox is simple. The `Txbox` modules provides four
  CRUD-like functions for managing transactions: `create/2`, `update/2`,
  `find/2` and `all/2`.

  To add a transaction to Txbox, the minimum required is to give a `txid`.

      iex> Txbox.create(%{
      ...>   txid: "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110"
      ...> })
      {:ok, %Tx{}}

  When a channel name is ommitted, transactions are added to the `default_channel/0`
  (`"txbox"`), but by specifiying a channel name as the first argument, the
  transaction will be added to that channel. You can provide additional metadata
  about the transaction, as well as attach the raw transaction binary.

      iex> Txbox.create("photos", %{
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

  The transaction can be retrieved by the `txid`.

      iex> Txbox.find("6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110")
      {:ok, %Tx{}}

  As before, omitting the channel scopes the query to the `default_channel/0`
  (`"txbox"`). Alterntively you can pass the channel name as the first argument,
  or use `"_"` which is the TXT syntax for global scope.

      iex> Txbox.find("_", "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110")
      {:ok, %Tx{}}

  A list of transactions can be returned using `all/2`. The second parameter
  must be a `t:map/0` of query parameters to filter and search by.

      iex> Txbox.all("photos", %{
      ...>   from: 636400,
      ...>   tagged: "hubble",
      ...>   limit: 5
      ...> })
      {:ok, [%Tx{}, ...]}

  A full text search can be made by using the `:search` filter parameter.

      iex> Txbox.all("_", %{
      ...>   search: "hubble deep field"
      ...> })
      {:ok, [%Tx{}, ...]}

  ### Filtering and searching

  Txbox adopts the same syntax and query modifiers [used by TXT](https://txt.network/#/?id=c-queries).
  Txbox automatically normalizes the query map, so keys can be specifiied either
  as atoms or strings. Here are a few examples:

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

  ## Transaction state machine and miner API integration

  Under the hood, Txbox is packed with a powerful state machine with automatic
  miner API integration.

  ![Txbox state machine](https://github.com/libitx/txbox/raw/master/media/state-machine.png)

  When creating a new transaction, you can set its state to one of the
  following values.

  * `"pending"` - If no state is specified, the default state is `"pending"`.
  Pending transactions can be considered draft or incomplete transactions. Draft
  transactions can be updated, and will not be pushed to miners unless the state
  changes.
  * `"queued"` - Under the `"queued"` state, a transaction will be asynchronously
  pushed to the configured miner API in the background. Depending on the miner
  response, the state will transition to `"pushed"` or `"failed"`.
  * `"pushed"` - If the state is specified as `"pushed"`, this tells Txbox the
  transaction is already accepted by miners. In the background, Txbox will poll
  the configured miner API until a response confirms the transaction is in a
  block.

  The miner API queue and processing occurs automatically in a background
  process, run under your application's supervision tree. For details refer to
  `Txbox.Mapi.Queue` and `Txbox.Mapi.Processor`.

  Each historic miner API response is saved associated to the transaction. The
  most recent response is always preloaded with the transaction. This allows
  you to inspect any messages or errors given by miners.

      iex> {:ok, tx} Txbox.find("6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110")
      iex> tx.status
      %Txbox.Transactions.MapiResponse{
        type: "push",
        payload: %{
          "return_result" => "failure",
          "return_description" => "Not enough fees",
          ...
        },
        public_key: "03e92d3e5c3f7bd945dfbf48e7a99393b1bfb3f11f380ae30d286e7ff2aec5a270",
        signature: "3045022100c8e7f9369545b89c978afc13cc19fc6dd6e1cd139d363a6b808141e2c9fccd2e02202e12f4bf91d10bf7a45191e6fe77f50d7b5351dae7e0613fecc42f61a5736af8",
        verified: true
      }
  """
  @doc false
  use Supervisor
  alias Txbox.Transactions
  alias Txbox.Transactions.Tx


  @default_channel "txbox"


  @doc """
  Returns the default channel (`"txbox"`).
  """
  @spec default_channel() :: String.t
  def default_channel(), do: @default_channel


  @doc """
  Starts the Txbox process linked to the current process.
  """
  @spec start_link(keyword) :: Supervisor.on_start
  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end


  @impl true
  def init(opts) do
    children = [
      Txbox.MapiStatus.Queue,
      {Txbox.MapiStatus.Processor, opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end


  @doc false
  def all(query \\ %{})
  def all(query) when is_map(query), do: all(@default_channel, query)
  def all(channel) when is_binary(channel), do: all(channel, %{})

  @doc """
  Finds a list of transactions, scoped by the specified channel and/or filtered
  by the map of query options.

  If the channel is omitted, it defaults to `default_channel/0`. Alernatively,
  the channel can be specified as `"_"` which is the TXT syntax for the global
  scope.

  ## Query options

  The accepted query options are: (keys can be atoms or strings)

  * `:search` - Full text search made on trasactions' tags and meta data
  * `:tagged` - Filter transactions by the given tag or tags
  * `:from` - The block height from which to filter transactions by
  * `:to` - The block height to which to filter transactions by
  * `:at` - The block height at which to filter transactions by exactly
  * `:order` - The attribute to sort transactions by
  * `:limit` - The maximum number of transactions to return
  * `:offset` - The start offset from which to return transactions (for pagination)

  ## Examples

  Find all transactions from the specified block height in the default channel (`"txbox"`)

      iex> Txbox.all(%{from: 636400})
      {:ok, [%Tx{}, ...]}

  Find all transactions in the specified channel with a combination of filters

      iex> Txbox.all("photos", %{from: 636400, tagged: "hubble", limit: 5})
      {:ok, [%Tx{}, ...]}

  Find all transactions in any channel unfiltered

      iex> Txbox.all("_")
      {:ok, [%Tx{}, ...]}

  Make full text search against the transactions' meta data and tag names.

      iex> Txbox.all(%{search: "hubble deep field"})
      {:ok, [%Tx{}, ...]}
  """
  @spec all(String.t, map) :: {:ok, list(Tx.t)}
  def all(channel, %{} = query) do
    txns = Tx
    |> Transactions.channel(channel)
    |> Transactions.list_tx(query)

    {:ok, txns}
  end


  @doc """
  Finds a transaction by it's txid, scoped by the specified channel.

  If the channel is omitted, it defaults to `default_channel/0`. Alernatively,
  the channel can be specified as `"_"` which is the TXT syntax for the global
  scope.

  ## Examples

  Find within the default channel (`"txbox"`)

      iex> Txbox.find("6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110")
      {:ok, %Tx{}}

  Find within the specified channel

      iex> Txbox.find("photos", "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110")
      {:ok, %Tx{}}

  Find within the global scope

      iex> Txbox.find("_", "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110")
      {:ok, %Tx{}}
  """
  @spec find(String.t, String.t) :: {:ok, Tx.t} | {:error, :not_found}
  def find(channel \\ @default_channel, txid) when is_binary(txid) do
    tx = Tx
    |> Transactions.channel(channel)
    |> Transactions.get_tx(txid)

    case tx do
      %Tx{} = tx ->
        {:ok, tx}

      nil ->
        {:error, :not_found}
    end
  end


  @doc "Finds a transaction by it's txid, scoped by the specified channel."
  @deprecated "Use find/2 instead"
  @spec get(String.t, String.t) :: {:ok, Tx.t} | {:error, :not_found}
  def get(channel \\ @default_channel, txid) when is_binary(txid),
    do: find(channel, txid)


  @doc """
  Adds the given transaction parameters into Txbox, within the specified channel.

  If the channel is omitted, it defaults to `default_channel/0`.

  ## Examples

  Add a transaction txid within the default channel (`"txbox"`).

      iex> Txbox.create(%{
      ...>   txid: "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110"
      ...> })
      {:ok, %Tx{}}

  Add a transaction with associated meta data, within a specified channel.

      iex> Txbox.create("photos", %{
      ...>   txid: "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110",
      ...>   tags: ["hubble", "universe"],
      ...>   meta: %{
      ...>     title: "Hubble Ultra-Deep Field"
      ...>   },
      ...>   data: %{
      ...>     bitfs: "https://x.bitfs.network/6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110.out.0.3"
      ...>   }
      ...> })
      {:ok, %Tx{}}
  """
  @spec create(String.t, map) :: {:ok, Tx.t} | {:error, Ecto.Changeset.t}
  def create(channel \\ @default_channel, %{} = attrs) do
    attrs = Map.put(attrs, :channel, channel)

    case Transactions.create_tx(attrs) do
      {:ok, %Tx{} = tx} ->
        mapi_queue_push(tx)
        {:ok, tx}

      {:error, reason} ->
        {:error, reason}
    end
  end


  @doc "Adds the given transaction parameters into Txbox, within the specified channel."
  @deprecated "Use create/2 instead"
  @spec set(String.t, map) :: {:ok, Tx.t} | {:error, Ecto.Changeset.t}
  def set(channel \\ @default_channel, %{} = attrs),
    do: create(channel, attrs)


  @doc """
  TODO
  """
  @spec update(Tx.t, map) :: {:ok, Tx.t} | {:error, Ecto.Changeset.t}
  def update(%Tx{} = tx, %{} = attrs) do
    case Transactions.update_tx(tx, attrs) do
      {:ok, %Tx{} = tx} ->
        mapi_queue_push(tx)
        {:ok, tx}

      {:error, reason} ->
        {:error, reason}
    end
  end


  # TODO
  defp mapi_queue_push(%Tx{state: state} = tx)
    when state == "queued"
    or state == "pushed",
    do: Txbox.Mapi.Queue.push(tx)

  defp mapi_queue_push(%Tx{}), do: false

end
