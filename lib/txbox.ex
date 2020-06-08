defmodule Txbox do
  @moduledoc """
  Documentation for `Txbox`.
  """
  use Supervisor
  alias Txbox.Transactions
  alias Txbox.Transactions.Tx


  @default_channel "txbox"
  @query_keys [:channel, :tagged, :from, :to, :at, :order, :limit, :offset]


  @doc """
  TODO
  """
  @spec default_channel() :: String.t  
  def default_channel(), do: @default_channel


  @doc """
  TODO
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


  @doc """
  TODO
  """
  def add(channel \\ @default_channel, %{} = attrs) do
    attrs = Map.put(attrs, :channel, channel)

    case Transactions.create(attrs) do
      {:ok, %Tx{} = tx} ->
        Txbox.MapiStatus.Queue.push(tx)
        {:ok, tx}

      {:error, reason} ->
        {:error, reason}
    end
  end


  @doc """
  TODO
  """
  def get(channel \\ @default_channel, txid) when is_binary(txid) do
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
  def all(query) when is_map(query), do: all(@default_channel, query)
  def all(channel) when is_binary(channel), do: all(channel, %{})
  def all(channel, %{} = query) do
    res = query
    |> Map.put(:channel, channel)
    |> Transactions.query
    |> Transactions.all

    {:ok, res}
  end


  

end
