defmodule Txbox.Transactions do
  @moduledoc """
  Collection of functions for composing Ecto queries.

  The functions in this module can be broadly split into two types, expressions
  and queries.

  ## Expressions

  Expression functions can be used to compose queries following the Elixir
  pipeline syntax.

      iex> Tx
      ...> |> Transactions.confirmed(true)
      ...> |> Transactions.tagged(["space", "photos"])
      %Ecto.Query{}

  ## Queries

  Query functions interface with the repo and either create or return records
  from the repo.

      iex> Transactions.list_tx()
      [%Tx{}, ...]
  """
  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Txbox.Transactions.{Tx, MapiResponse}


  @query_keys [:channel, :search, :tagged, :from, :to, :at, :order, :limit, :offset]


  @doc """
  Returns the application's configured Repo.

  Ensure your application's Repo is configured in `config.exs`:

      config :txbox, repo: MyApp.Repo
  """
  @spec repo() :: module
  def repo(), do: Application.get_env(:txbox, :repo)


  @doc """
  Get a transaction by it's internal ID or TXID.

  Can optionally pass a `Ecto.Queryable.t` as the first argument to compose
  queries.

  ## Examples

      # Find a tx by it's Txbox uuid
      iex> tx = Transactions.find_tx "e9d356cf-47e9-47c3-bfc8-c12673877302"

      # Composed query, found by txid
      iex> tx = Transactions.channel("mychannel)
      ...> |> Transactions.confirmed(true)
      ...> |> Transactions.find_tx("6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110")
  """
  @doc group: :query
  @spec get_tx(Ecto.Queryable.t, binary) :: Ecto.Schema.t | nil
  def get_tx(tx \\ Tx, id) when is_binary(id) do
    pre_qry = from(r in MapiResponse, order_by: [desc: r.inserted_at])
    qry = preload(tx, mapi_status: ^pre_qry)

    case String.match?(id, ~r/^[a-f0-9]{64}$/i) do
      true ->
        qry
        |> repo().get_by(txid: id)

      false ->
        qry
        |> repo().get(id)
    end
  end


  @doc false
  def list_tx(), do: repo().all(Tx)
  @doc false
  def list_tx(Tx = tx), do: repo().all(tx)
  def list_tx(%Ecto.Query{} = tx), do: repo().all(tx)

  @doc """
  Returns a list of transactions.

  Can optionally pass a `Ecto.Queryable.t` as the first argument to compose
  queries. If a map of query options is given as a secndon argument, the query
  is filtered by those arguments.

  ## Examples

      iex> txns = Transactions.channel("mychannel)
      ...> |> Transactions.confirmed(true)
      ...> |> Transactions.list_tx
  """
  @doc group: :query
  @spec list_tx(Ecto.Queryable.t, map) :: list(Ecto.Schema.t)
  def list_tx(tx \\ Tx, params) when is_map(params) do
    pre_qry = from(r in MapiResponse, order_by: [desc: r.inserted_at])
    tx
    |> preload(mapi_status: ^pre_qry)
    |> query(%{} = params)
    |> repo().all
  end


  @doc """
  Creates a transaction from the given params.

  Returns an `:ok` / `:error` tuple response.

  ## Examples

      iex> {:ok, tx} = Transactions.create_tx(%{
      ...>   txid: "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110",
      ...>   channel: "mychannel"
      ...> })
  """
  @doc group: :query
  @spec create_tx(map) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t()}
  def create_tx(attrs \\ %{}) do
    %Tx{}
    |> Tx.changeset(attrs)
    |> repo().insert
  end


  @doc """
  TODO
  """
  @doc group: :query
  @spec update_tx(Ecto.Schema.t, map) ::
    {:ok, Ecto.Schema.t} |
    {:error, Ecto.Changeset.t()}
  def update_tx(%Tx{} = tx, attrs \\ %{}) do
    tx
    |> Tx.changeset(attrs)
    |> repo().update
    |> case do
      {:ok, tx} ->
        pre_qry = from(r in MapiResponse, order_by: [desc: r.inserted_at])
        {:ok, repo().preload(tx, [mapi_status: pre_qry], force: true)}

      error ->
        error
    end
  end


  @doc """
  TODO
  """
  @doc group: :query
  @spec update_tx_state(Ecto.Schema.t, String.t) ::
    {:ok, Ecto.Schema.t} |
    {:error, Ecto.Changeset.t()}
  def update_tx_state(%Tx{} = tx, state),
    do: update_tx(tx, %{state: state})


  @doc """
  TODO
  """
  @doc group: :query
  @spec update_tx_state(Ecto.Schema.t, String.t, map) ::
    {:ok, Ecto.Schema.t} |
    {:error, Ecto.Changeset.t} |
    {:error, %{required(atom) => Ecto.Changeset.t}}
  def update_tx_state(%Tx{state: "pending"} = tx, state, mapi_response) do
    mapi = Ecto.build_assoc(tx, :mapi_responses)
    Multi.new
    |> Multi.insert(:mapi_response, MapiResponse.push_changeset(mapi, mapi_response))
    |> Multi.update(:tx, Fsmx.transition_changeset(tx, state, mapi_response))
    |> update_tx_state
  end

  def update_tx_state(%Tx{state: "pushed"} = tx, state, mapi_response) do
    mapi = Ecto.build_assoc(tx, :mapi_responses)
    Multi.new
    |> Multi.insert(:mapi_response, MapiResponse.status_changeset(mapi, mapi_response))
    |> Multi.update(:tx, Fsmx.transition_changeset(tx, state, mapi_response))
    |> update_tx_state
  end

  def update_tx_state(%Tx{} = tx, state, _mapi_response) do
    Multi.new
    |> Multi.update(:tx, Fsmx.transition_changeset(tx, state))
    |> update_tx_state
  end

  defp update_tx_state(%Multi{} = multi) do
    case repo().transaction(multi) do
      {:ok, %{tx: tx}} ->
        pre_qry = from(r in MapiResponse, order_by: [desc: r.inserted_at])
        {:ok, repo().preload(tx, [mapi_status: pre_qry], force: true)}

      {:error, name, changeset, _} ->
        {:error, %{name => changeset}}

      {:error, error} ->
        {:error, error}
    end
  end


  @doc """
  Deletes the given transaction from the repo.

  Returns an `:ok` / `:error` tuple response.

  ## Examples

      iex> {:ok, tx} = Transactions.get_tx("6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110")
      ...> |> Transactions.delete_tx
  """
  @doc group: :query
  @spec delete_tx(Ecto.Schema.t) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t()}
  def delete_tx(%Tx{} = tx),
    do: repo().delete(tx)


  @doc """
  Returns a list of transactions filtered by the given search term.

  Performs a full text search on the transactions' metadata. Can optionally pass
  a `Ecto.Queryable.t` as the first argument to compose queries.

  ## Examples

      iex> {:ok, txns} = Transactions.search_tx("unwriter bitpic")
  """
  @doc group: :query
  @spec search_tx(Ecto.Queryable.t, String.t) :: list(Ecto.Schema.t)
  def search_tx(tx \\ Tx, term) when is_binary(term) do
    tx
    |> search(term)
    |> list_tx
  end


  @doc """
  Returns a list of transactions that must be pushed or have their status
  confirmed by mAPI.

  This is used internally by `Txbox.Mapi.Queue` to fetch transactions for
  automatic processing.

  ## Options

  The accepted options are:

  * `:max_status_attempts` - How many times to poll mAPI for confirmation status. Defaults to `20`.
  * `:retry_status_after` - Number of seconds before polling mAPI for confirmation status. Defaults to `300` (5 minutes).
  """
  @doc group: :query
  @spec list_tx_for_mapi(keyword) :: list(Ecto.Schema.t)
  def list_tx_for_mapi(opts \\ []) do
    max_status_attempts = Keyword.get(opts, :max_status_attempts, 20)
    retry_status_after = Keyword.get(opts, :retry_status_after, 300)
    retry_datetime = DateTime.now!("Etc/UTC") |> DateTime.add(-retry_status_after)

    pre_qry = from(r in MapiResponse, order_by: [desc: r.inserted_at])

    Tx
    |> join(:left, [t], r in subquery(pre_qry), on: r.tx_guid == t.guid)
    |> preload(mapi_status: ^pre_qry)
    |> where([t],
        t.state == "pending"
        and fragment("SELECT COUNT(*) FROM txbox_mapi_responses WHERE type = ? AND tx_guid = ?", "push", t.guid) < 1)
    |> or_where([t, r],
        t.state == "pushed"
        and (is_nil(r) or r.inserted_at < ^retry_datetime)
        and fragment("SELECT COUNT(*) FROM txbox_mapi_responses WHERE type = ? AND tx_guid = ?", "status", t.guid) < ^max_status_attempts)
    |> list_tx
  end


  @doc """
  Query by the given query map.
  """
  @doc group: :expression
  @spec query(Ecto.Queryable.t, map) :: Ecto.Queryable.t
  def query(tx, %{} = qry) do
    qry
    |> normalize_query
    |> Enum.reduce(tx, &build_query/2)
  end


  @doc """
  Search by the given term.
  """
  @doc group: :expression
  @spec search(Ecto.Queryable.t, String.t) :: Ecto.Queryable.t
  def search(tx, term) when is_binary(term) do
    tx
    |> where(fragment("search_vector @@ plainto_tsquery(?)", ^term))
    |> order_by(fragment("ts_rank(search_vector, plainto_tsquery(?)) DESC", ^term))
  end


  @doc """
  Query by the given channel name.
  """
  @doc group: :expression
  @spec channel(Ecto.Queryable.t, binary) :: Ecto.Queryable.t
  def channel(tx, "_"), do: tx
  def channel(tx, chan)
    when is_binary(chan),
    do: where(tx, channel: ^chan)


  @doc """
  Query by the given tag or list of tags.

  Optionally tags can be specified as a comma seperated string
  """
  @doc group: :expression
  @spec tagged(Ecto.Queryable.t, list | String.t) :: Ecto.Queryable.t
  def tagged(tx, tags) when is_list(tags),
    do: where(tx, fragment("tags @> ?", ^tags))

  def tagged(tx, tags) when is_binary(tags),
    do: tagged(tx, String.split(tags, ",") |> Enum.map(&String.trim/1))


  @doc """
  Query by the transaction confirmation status.
  """
  @doc group: :expression
  @spec confirmed(Ecto.Queryable.t, boolean) :: Ecto.Queryable.t
  def confirmed(tx, conf \\ true)

  def confirmed(tx, true),
    do: where(tx, [t], t.state == "confirmed")

  def confirmed(tx, false),
    do: where(tx, [t], t.state != "confirmed")


  # Normalizes a query map by converting all keys to strings, taking the
  # allowed keys, and converting back to atoms
  defp normalize_query(query) do
    query
    |> Map.new(fn {k, v} -> {normalize_key(k), v} end)
    |> Map.take(Enum.map(@query_keys, &Atom.to_string/1))
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end

  # Normalizes the given key as a string
  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: key


  # Composes a query from the given tuple, adding to the existing queryable
  defp build_query({:search, term}, tx), do: search(tx, term)

  defp build_query({:channel, chan}, tx), do: channel(tx, chan)

  defp build_query({:tagged, tags}, tx), do: tagged(tx, tags)

  defp build_query({:from, height}, tx),
    do: where(tx, [t], t.block_height >= ^height)

  defp build_query({:to, height}, tx),
    do: where(tx, [t], t.block_height <= ^height)

  defp build_query({:at, true}, tx), do: confirmed(tx, true)
  defp build_query({:at, "-null"}, tx), do: confirmed(tx, true)
  defp build_query({:at, false}, tx), do: confirmed(tx, false)
  defp build_query({:at, nil}, tx), do: confirmed(tx, false)
  defp build_query({:at, "null"}, tx), do: confirmed(tx, false)
  defp build_query({:at, height}, tx),
    do: where(tx, [t], t.block_height == ^height)

  defp build_query({:order, "created_at"}, tx),
    do: order_by(tx, asc: :inserted_at)
  defp build_query({:order, "inserted_at"}, tx),
    do: order_by(tx, asc: :inserted_at)
  defp build_query({:order, "-created_at"}, tx),
    do: order_by(tx, desc: :inserted_at)
  defp build_query({:order, "-inserted_at"}, tx),
    do: order_by(tx, desc: :inserted_at)
  defp build_query({:order, "i"}, tx),
    do: order_by(tx, asc: :block_height)
  defp build_query({:order, "block_height"}, tx),
    do: order_by(tx, asc: :block_height)
  defp build_query({:order, "-i"}, tx),
    do: order_by(tx, desc: :block_height)
  defp build_query({:order, "-block_height"}, tx),
    do: order_by(tx, desc: :block_height)

  defp build_query({:order, _order}, tx), do: tx
  defp build_query({:limit, num}, tx), do: limit(tx, ^num)
  defp build_query({:offset, num}, tx), do: offset(tx, ^num)

end
