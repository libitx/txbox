defmodule Bitbox.TxStatus.Processor do
  @moduledoc """
  TODO
  """
  require Logger
  use GenStage
  alias Bitbox.Transactions
  alias Bitbox.TxStatus.Queue


  @max_retries 12
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


  defp check_tx_status({txid, _attempts} = event, state) do
    with {:ok, tx} <- Bitbox.get("_", txid),
         {:ok, env} <- Manic.TX.status(state.miner, txid, as: :envelope),
         {:ok, payload} <- Manic.JSONEnvelope.parse_payload(env)
    do
      Transactions.update_status(tx, %{
        payload: payload,
        public_key: env.public_key,
        signature: env.signature,
        verified: true
      })
      unless tx.confirmed?, do: requeue_event(event, state)
    else
      {:error, :not_found} ->
        Logger.error "TX not found: #{txid}"

      {:error, error} ->
        Logger.error "mAPI error: #{txid} : #{inspect error}"
        requeue_event(event, state)
    end
  end

  defp requeue_event({txid, attempts}, %{max_retries: max_retries, retry_after: retry_after})
    when attempts < max_retries,
    do: Process.send_after(Queue, {:push, {txid, attempts+1}}, retry_after)

  defp requeue_event(_event, _state), do: :ok

end
