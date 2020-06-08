defmodule Bitbox.Transactions do
  import Ecto.Query, warn: false
  alias Bitbox.Transactions.Tx

  @repo Application.get_env(:bitbox, :repo)


  @doc """
  TODO
  """
  @spec get(Ecto.Queryable.t, binary) :: Ecto.Schema.t | nil
  def get(tx \\ Tx, txid) when is_binary(txid),
    do: @repo.get_by(tx, txid: txid)


  @doc """
  TODO
  """
  @spec all(Ecto.Queryable.t) :: [Ecto.Schema.t]
  def all(tx \\ Tx), do: @repo.all(tx)


  @doc """
  TODO
  """
  @spec create(map) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    %Tx{}
    |> Tx.changeset(attrs)
    |> @repo.insert()
  end


  @doc """
  TODO
  """
  @spec update_status(Ecto.Schema.t, map) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t()}
  def update_status(%Tx{} = tx, attrs \\ %{}) do
    tx
    |> Tx.status_changeset(attrs)
    |> @repo.update()
  end


  @doc """
  TODO
  """
  @spec delete(Ecto.Schema.t) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t()}
  def delete(%Tx{} = tx),
    do: @repo.delete(tx)


  @doc """
  TODO
  """
  @spec get_unconfirmed_txids() :: [Ecto.Schema.t]
  def get_unconfirmed_txids() do
    "bitbox_txns"
    |> select([:txid])
    |> is_confirmed(false)
    |> @repo.all
    |> Enum.map(& &1.txid)
  end

  # TODO
  def pending_mapi(tx \\ Tx) do
    tx
    |> is_confirmed(false)
    |> where([t], t.mapi_attempt < 20)
  end


  @doc """
  TODO
  """
  @spec in_channel(Ecto.Queryable.t, binary) :: Ecto.Queryable.t
  def in_channel(tx, channel)
    when is_binary(channel),
    do: where(tx, channel: ^channel)


  @doc """
  TODO
  """
  @spec tagged_with(Ecto.Queryable.t, list | String.t) :: Ecto.Queryable.t
  def tagged_with(tx, tags) when is_list(tags),
    do: where(tx, fragment("tags @> ?", ^tags))

  def tagged_with(tx, tags) when is_binary(tags),
    do: tagged_with(tx, String.split(tags, ",") |> Enum.map(&String.trim/1))


  @doc """
  TODO
  """
  @spec is_confirmed(Ecto.Queryable.t, boolean) :: Ecto.Queryable.t
  def is_confirmed(tx, conf \\ true)

  def is_confirmed(tx, true),
    do: where(tx, [t], not is_nil(t.block_height))

  def is_confirmed(tx, false),
    do: where(tx, [t], is_nil(t.block_height))


  @doc """
  TODO
  """
  @spec search_by(Ecto.Queryable.t, String.t) :: Ecto.Queryable.t
  def search_by(tx \\ Tx, term) when is_binary(term) do
    tx
    |> where(fragment("search_vector @@ plainto_tsquery(?)", ^term))
    |> order_by(fragment("ts_rank(search_vector, plainto_tsquery(?)) DESC", ^term))
  end


  @doc """
  TODO
  """
  @spec query(Ecto.Queryable.t, map) :: Ecto.Queryable.t
  def query(tx \\ Tx, %{} = query) do
    Enum.reduce(query, tx, &build_query/2)
  end


  # TODO
  defp build_query({:channel, "_"}, tx), do: tx
  defp build_query({:channel, channel}, tx), do: where(tx, channel: ^channel)

  defp build_query({:tagged, tags}, tx), do: tagged_with(tx, tags)

  defp build_query({:from, height}, tx),
    do: where(tx, [t], t.block_height >= ^height)

  defp build_query({:to, height}, tx),
    do: where(tx, [t], t.block_height <= ^height)

  defp build_query({:at, true}, tx), do: is_confirmed(tx, true)
  defp build_query({:at, "-null"}, tx), do: is_confirmed(tx, true)
  defp build_query({:at, false}, tx), do: is_confirmed(tx, false)
  defp build_query({:at, nil}, tx), do: is_confirmed(tx, false)
  defp build_query({:at, "null"}, tx), do: is_confirmed(tx, false)
  defp build_query({:at, height}, tx),
    do: where(tx, [t], t.block_height == ^height)

  defp build_query({:order, "created_at"}, tx),
    do: order_by(tx, asc: :inserted_at)
  defp build_query({:order, "-created_at"}, tx),
    do: order_by(tx, desc: :inserted_at)
  defp build_query({:order, "i"}, tx),
    do: order_by(tx, asc: :block_height)
  defp build_query({:order, "-i"}, tx),
    do: order_by(tx, desc: :block_height)

  defp build_query({:order, _order}, tx), do: tx
  defp build_query({:limit, num}, tx), do: limit(tx, ^num)
  defp build_query({:offset, num}, tx), do: offset(tx, ^num)

end
