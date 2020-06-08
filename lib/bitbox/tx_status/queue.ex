defmodule Bitbox.TxStatus.Queue do
  @moduledoc """
  TODO
  """
  use GenStage
  alias Bitbox.Transactions
  alias Bitbox.Transactions.Tx


  @doc """
  TODO
  """
  def start_link(_opts \\ []) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  @doc """
  TODO
  """
  def push(%Tx{} = tx),
    do: GenStage.cast(__MODULE__, {:push, tx})


  # Callbacks


  @impl true
  def init(_) do
    queue = Transactions.pending_mapi()
    |> Transactions.all
    |> Qex.new

    state = %{
      queue: queue,
      demand: 0
    }

    {:producer, state}
  end


  @impl true
  def handle_cast({:push, %Tx{} = tx}, state) do
    update_in(state.queue, & Qex.push(&1, tx))
    |> take_demanded_events
  end


  @impl true
  def handle_info({:push, %Tx{} = tx}, state) do
    update_in(state.queue, & Qex.push(&1, tx))
    |> take_demanded_events
  end


  @impl true
  def handle_demand(demand, state) when demand > 0 do
    update_in(state.demand, & &1 + demand)
    |> take_demanded_events
  end


  # TODO
  defp take_demanded_events(%{queue: queue} = state) do
    demand = :queue.len(queue.data) |> min(state.demand)
    {demanded, queue} = Qex.split(queue, demand)
    state = update_in(state.demand, & &1 - :queue.len(demanded.data))
    |> Map.put(:queue, queue)

    {:noreply, Enum.to_list(demanded), state}
  end

end
