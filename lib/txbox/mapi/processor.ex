defmodule Txbox.Mapi.Processor do
  @moduledoc """
  TODO
  """
  require Logger
  use GenStage
  alias Txbox.Transactions
  alias Txbox.Transactions.Tx

  defstruct miner: nil

  @default_miner :taal


  @doc """
  Starts the Queue Processor, linked to the current process.
  """
  @spec start_link(keyword) :: GenServer.on_start
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end


  # Callbacks


  @impl true
  def init(opts) do
    miner = Keyword.get(opts, :miner, @default_miner)
    |> Manic.miner

    state = %__MODULE__{miner: miner}
    {:consumer, state, subscribe_to: [{Txbox.Mapi.Queue, max_demand: 1}]}
  end


  @impl true
  def handle_events(events, _, state) do
    Enum.each(events, fn
      %Tx{state: "pending"} = tx -> mapi_push(tx, state)
      %Tx{state: "pushed"} = tx -> mapi_status(tx, state)
    end)
    {:noreply, [], state}
  end


  # TODO
  defp mapi_push(%Tx{txid: txid, rawtx: rawtx} = tx, %{miner: miner}) do
    rawtx = Base.encode16(rawtx, case: :lower)

    with {:ok, env} <- Manic.TX.push(miner, rawtx, as: :envelope),
         {:ok, payload} <- Manic.JSONEnvelope.parse_payload(env)
    do
      state = if payload["return_result"] == "success", do: "pushed", else: "failed"
      Transactions.update_tx_state(tx, state, Map.put(env, :payload, payload))
    else
      {:error, error} ->
        Logger.error "mAPI push error: #{txid} : #{inspect error}"
    end
  end


  # TODO
  defp mapi_status(%Tx{txid: txid} = tx, %{miner: miner}) do
    with {:ok, env} <- Manic.TX.status(miner, txid, as: :envelope),
         {:ok, payload} <- Manic.JSONEnvelope.parse_payload(env)
    do
      state = if payload["return_result"] == "success"
        and is_integer(payload["block_height"])
        and payload["block_height"] > 0,
        do: "confirmed",
        else: "pushed"
      Transactions.update_tx_state(tx, state, Map.put(env, :payload, payload))
    else
      {:error, error} ->
        Logger.error "mAPI push error: #{txid} : #{inspect error}"
    end
  end

end
