defmodule Txbox.Transactions.Tx do
  @moduledoc """
  Transaction schema module.

  Txbox adds a single table to your database containing all of the transaction,
  channel and meta data.

  For any transaction, the only required attribute is the `txid`. If no channel
  is specified, the transaction will be added to the `Txbox.default_channel/0`.
  Optionally any of the following attributes can be set:

  * `:rawtx` - The raw transaction data. Must be given as a raw `t:binary/0`, not a hex encoded string.
  * `:tags` - A list of tags which can be used for organising and filtering transactions.
  * `:meta` - A map containing structured metadata about the transaction. See `t:Txbox.Transactions.Meta.t/0`.
  * `:data` - A map containing any other arbitarry fields.

  When searching Txbox, the data from `:tags` and `:meta` are incorporated into
  full text search.

  Txbox automatically syncs the transaction with your configured miner, and
  updates the `:status` attribute with a cached response from the miner's Merchant
  API. See `t:Txbox.Transactions.Status.t/0`.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Txbox.Transactions.{Meta, MapiResponse, Status}


  @typedoc "Transaction schema"
  @type t :: %__MODULE__{
    id: binary,
    state: String.t,
    txid: String.t,
    rawtx: binary,
    channel: String.t,
    tags: list(String.t),
    meta: Meta.t,
    data: map,
    block_height: integer,
    mapi_attempted_at: DateTime.t,
    inserted_at: DateTime.t,
    updated_at: DateTime.t
  }


  @default_channel "txbox"
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "txbox_txns" do
    field :state, :string
    field :txid, :string
    field :rawtx, :binary
    field :channel, :string, default: @default_channel
    field :tags, {:array, :string}
    field :data, :map
    field :block_height, :integer
    field :mapi_attempted_at, :utc_datetime

    embeds_one :meta, Meta, on_replace: :update
    has_many :mapi_responses, MapiResponse
    has_one :mapi_status, MapiResponse

    timestamps()
  end


  @doc false
  def changeset(tx, attrs) do
    tx
    |> cast(attrs, [:txid, :rawtx, :channel, :tags, :data])
    |> cast_embed(:meta, with: &Meta.changeset/2)
    |> validate_required([:txid, :channel])
    |> validate_format(:txid, ~r/^[a-f0-9]{64}$/i)
    |> validate_format(:channel, ~r/^\w[\w\-\/]*$/)
  end


  @doc false
  def status_changeset(tx, nil) do
    tx
    |> cast(%{}, [])
    |> put_mapi_attempted
  end

  def status_changeset(tx, %{} = attrs) do
    tx
    |> cast(%{status: attrs}, [])
    |> cast_embed(:status, with: &Status.changeset/2)
    |> put_block_height
    |> put_mapi_attempted
    |> put_mapi_completed
  end


  # Puts the block height on the tx, if present in the status payload
  defp put_block_height(%{valid?: true,
    changes: %{
      status: %{
        changes: %{payload: payload}
    }}} = changeset)
  do
    i = payload["block_height"] || payload[:block_height]
    put_change(changeset, :block_height, i)
  end

  defp put_block_height(changeset), do: changeset


  # Puts mapi attempt counter and timestamp
  defp put_mapi_attempted(%{data: tx} = changeset) do
    now = DateTime.utc_now |> DateTime.truncate(:second)
    changeset
    |> put_change(:mapi_attempt, tx.mapi_attempt+1)
    |> put_change(:mapi_attempted_at, now)
  end


  # Puts mapi complete timestamp
  defp put_mapi_completed(%{valid?: true, changes: %{block_height: i}} = changeset)
    when is_integer(i)
  do
    now = DateTime.utc_now |> DateTime.truncate(:second)
    changeset
    |> put_change(:mapi_completed_at, now)
  end

  defp put_mapi_completed(changeset), do: changeset

end
