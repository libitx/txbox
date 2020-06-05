defmodule Bitbox.Transactions do
  import Ecto.Query, warn: false
  alias Bitbox.Transactions.Tx

  @repo Application.get_env(:bitbox, :repo)


  @doc """
  TODO
  """
  @spec get(Ecto.Queryable.t, binary) :: Ecto.Schema.t | nil
  def get(tx \\ Tx, txid) when is_binary(txid) do
    case @repo.get(tx, txid) do
      %Tx{} = tx ->
        Tx.fill_virtual_fields(tx)
      nil ->
        nil
    end
  end


  @doc """
  TODO
  """
  @spec all(Ecto.Queryable.t) :: [Ecto.Schema.t]
  def all(tx \\ Tx) do
    case @repo.all(tx) do
      txns when length(txns) > 0 ->
        Enum.map(txns, &Tx.fill_virtual_fields/1)
      [] ->
        []
    end
  end


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
    case tx |> Tx.status_changeset(attrs) |> @repo.update() do
      {:ok, tx} -> {:ok, Tx.fill_virtual_fields(tx)}
      {:error, changeset} -> {:error, changeset}
    end
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
    do: where(tx, [t], not fragment("(status->>'i')::integer") |> is_nil)

  def is_confirmed(tx, false),
    do: where(tx, [t], fragment("(status->>'i')::integer") |> is_nil)


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
  defp build_query({:channel, channel}, tx),
    do: where(tx, channel: ^channel)

  defp build_query({:tagged, tags}, tx), do: tagged_with(tx, tags)

  defp build_query({:from, height}, tx),
    do: where(tx, fragment("(status->>'i')::integer") >= ^height)

  defp build_query({:to, height}, tx),
    do: where(tx, fragment("(status->>'i')::integer") <= ^height)

  defp build_query({:at, true}, tx), do: is_confirmed(tx, true)
  defp build_query({:at, "-null"}, tx), do: is_confirmed(tx, true)
  defp build_query({:at, false}, tx), do: is_confirmed(tx, false)
  defp build_query({:at, nil}, tx), do: is_confirmed(tx, false)
  defp build_query({:at, "null"}, tx), do: is_confirmed(tx, false)
  defp build_query({:at, height}, tx),
    do: where(tx, fragment("(status->>'i')::integer") == ^height)

  defp build_query({:order, "created_at"}, tx),
    do: order_by(tx, asc: :inserted_at)
  defp build_query({:order, "-created_at"}, tx),
    do: order_by(tx, desc: :inserted_at)
  defp build_query({:order, "i"}, tx),
    do: order_by(tx, fragment("(status->>'i')::integer ASC"))
  defp build_query({:order, "-i"}, tx),
    do: order_by(tx, fragment("(status->>'i')::integer DESC"))

  defp build_query({:order, _order}, tx), do: tx

  defp build_query({:limit, num}, tx), do: limit(tx, ^num)

  defp build_query({:offset, num}, tx), do: offset(tx, ^num)

end
