defmodule Txbox.Mapi.Queue do
  @moduledoc """
  Miner API background queue.

  Once a minute the Queue process queries the database for any transactions that
  should be added to the mAPI queue.
  """
  use GenStage
  alias Txbox.Transactions
  alias Txbox.Transactions.Tx

  defstruct queue: :queue.new, demand: 0, retry: []


  @doc """
  Starts the Queue process, linked to the current process.
  """
  @spec start_link(keyword) :: GenServer.on_start
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end


  @doc """
  Pushes the given transaction to the end of queue.
  """
  @spec push(Tx.t) :: :ok
  def push(%Tx{} = tx),
    do: GenStage.cast(__MODULE__, {:push, tx})


  # Callbacks


  @impl true
  def init(opts) do
    retry_opts = Keyword.take(opts, [:max_status_attempts, :retry_status_after])
    state = %__MODULE__{retry: retry_opts}
    schedule_for_queue(0)
    {:producer, state}
  end


  @impl true
  def handle_cast({:push, %Tx{} = tx}, state) do
    update_in(state.queue, & :queue.in(tx, &1))
    |> take_demanded_events
  end


  @impl true
  def handle_demand(demand, state) when demand > 0 do
    update_in(state.demand, & &1 + demand)
    |> take_demanded_events
  end


  @impl true
  def handle_info(:populate_queue, state) do
    queue = Transactions.list_tx_for_mapi()
    |> :queue.from_list

    schedule_for_queue(60)

    update_in(state.queue, & :queue.join(&1, queue))
    |> take_demanded_events
  end


  # Splits the queue according to the demand, and emits the demanded tx.
  defp take_demanded_events(state) do
    demand = :queue.len(state.queue) |> min(state.demand)
    {demanded, remaining} = :queue.split(demand, state.queue)

    state = update_in(state.demand, & &1 - :queue.len(demanded))
    |> Map.put(:queue, remaining)

    {:noreply, :queue.to_list(demanded), state}
  end


  # Sends a :populate_queue message to self after the given number of seconds.
  defp schedule_for_queue(seconds),
    do: Process.send_after(self(), :populate_queue, seconds * 1000)

end
