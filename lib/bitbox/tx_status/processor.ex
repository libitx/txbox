defmodule Bitbox.TxStatus.Processor do
  @moduledoc """
  TODO
  """
  require Logger
  use GenStage
  alias Bitbox.Transactions
  alias Bitbox.Transactions.Tx
  alias Bitbox.TxStatus.Queue


  @max_retries 20
  @retry_after 300_000 # 5 minutes


  @doc """
  TODO
  """
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end


  # Callbacks


  @impl true
  def init(opts) do
    state = %{
      miner: Manic.miner(:taal),
      max_retries: Keyword.get(opts, :max_retries, @max_retries),
      retry_after: Keyword.get(opts, :retry_after, @retry_after)
    }
    {:consumer, state, subscribe_to: [{Queue, max_demand: 1}]}
  end


  @impl true
  def handle_events(events, _, state) do
    Enum.each(events, & check_tx_status(&1, state))
    {:noreply, [], state}
  end


  defp check_tx_status(%Tx{txid: txid} = tx, state) do
    with {:ok, env} <- Manic.TX.status(state.miner, txid, as: :envelope),
         {:ok, payload} <- Manic.JSONEnvelope.parse_payload(env)
    do
      {:ok, tx} = Transactions.update_status(tx, %{
        payload: payload,
        public_key: env.public_key,
        signature: env.signature,
        verified: true
      })
      requeue_event(tx, state)
    else
      {:error, error} ->
        Logger.error "mAPI error: #{txid} : #{inspect error}"
        {:ok, tx} = Transactions.update_status(tx, %{})
        requeue_event(tx, state)
    end
  end

  defp requeue_event(%Tx{mapi_attempted_at: attempts} = tx, %{
    max_retries: max_retries,
    retry_after: retry_after
  })
    when attempts < max_retries,
    do: Process.send_after(Queue, {:push, tx}, retry_after)

  defp requeue_event(_tx, _state), do: :ok

end
