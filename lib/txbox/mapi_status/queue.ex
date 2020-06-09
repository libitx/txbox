defmodule Txbox.MapiStatus.Queue do
  @moduledoc false
  use GenStage
  alias Txbox.Transactions
  alias Txbox.Transactions.Tx


  @doc """
  Starts the Queue process, linked to the current process.
  """
  @spec start_link(term) :: GenServer.on_start
  def start_link(_opts \\ []) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  @doc """
  Pushes the given transaction to the end of queue.
  """
  @spec push(Tx.t) :: :ok
  def push(%Tx{} = tx),
    do: GenStage.cast(__MODULE__, {:push, tx})


  # Callbacks


  @impl true
  def init(_) do
    queue = Transactions.list_pending_tx_for_mapi_check()
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


  # Splits the queue according to the demand, and emits the demanded tx
  defp take_demanded_events(%{queue: queue} = state) do
    demand = :queue.len(queue.data) |> min(state.demand)
    {demanded, queue} = Qex.split(queue, demand)
    state = update_in(state.demand, & &1 - :queue.len(demanded.data))
    |> Map.put(:queue, queue)

    {:noreply, Enum.to_list(demanded), state}
  end

end
