defmodule Bitbox.Transactions do
  import Ecto.Query, warn: false
  alias Bitbox.Transactions.Tx

  @repo Application.get_env(:bitbox, :repo)


  @doc """
  TODO
  """
  @spec get(Ecto.Queryable.t, binary) :: Ecto.Schema.t | nil
  def get(tx \\ Tx, txid)
    when is_binary(txid),
    do: @repo.get(tx, txid)


  @doc """
  TODO
  """
  @spec all(Ecto.Queryable.t) :: Ecto.Schema.t | nil
  def all(tx \\ Tx),
    do: @repo.all(tx)


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
  @spec by_channel(Ecto.Queryable.t, binary) :: Ecto.Queryable.t
  def by_channel(tx \\ Tx, channel)
    when is_binary(channel),
    do: where(tx, channel: ^channel)

end
