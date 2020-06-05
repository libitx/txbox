defmodule Bitbox do
  @moduledoc """
  Documentation for `Bitbox`.
  """
  alias Bitbox.Transactions
  alias Bitbox.Transactions.Tx


  @query_keys [:channel, :tagged, :from, :to, :at, :order, :limit, :offset]


  @doc """
  TODO
  """
  def add(channel \\ "bitbox", %{} = attrs) do
    attrs = Map.put(attrs, :channel, channel)

    case Transactions.create(attrs) do
      {:ok, %Tx{} = tx} ->
        Bitbox.TxStatus.Queue.push(tx)
        {:ok, tx}

      {:error, reason} ->
        {:error, reason}
    end
  end


  @doc """
  TODO
  """
  def get(channel \\ "bitbox", txid) when is_binary(txid) do
    case Transactions.query(%{channel: channel}) |> Transactions.get(txid) do
      %Tx{} = tx ->
        {:ok, tx}

      nil ->
        {:error, :not_found}
    end
  end


  @doc """
  TODO
  """
  def all(query \\ %{})
  def all(query) when is_map(query), do: all("bitbox", query)
  def all(channel) when is_binary(channel), do: all(channel, %{})
  def all(channel, %{} = query) do
    query = query
    |> normalize_query
    |> Map.put(:channel, channel)

    res = Transactions.query(query) |> Transactions.all
    {:ok, res}
  end


  defp normalize_query(query) do
    query
    |> Map.new(fn {k, v} -> {normalize_key(k), v} end)
    |> Map.take(Enum.map(@query_keys, &Atom.to_string/1))
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end

  def normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  def normalize_key(key), do: key

end
