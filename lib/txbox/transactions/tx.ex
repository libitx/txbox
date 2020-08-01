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
  alias Txbox.Transactions.{Meta, MapiResponse}

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
    inserted_at: DateTime.t,
    updated_at: DateTime.t
  }


  @default_state "draft"
  @default_channel "txbox"
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "txbox_txns" do
    field :state, :string, default: @default_state
    field :txid, :string
    field :rawtx, :binary
    field :channel, :string, default: @default_channel
    field :tags, {:array, :string}
    field :data, :map
    field :block_height, :integer

    embeds_one :meta, Meta, on_replace: :update
    has_many :mapi_responses, MapiResponse
    has_one :mapi_status, MapiResponse

    timestamps(type: :utc_datetime_usec)
  end


  use Fsmx.Struct, transitions: %{
    "draft"   => ["pending", "pushed"],
    "pending" => ["pushed", "failed"],
    "pushed"  => ["pushed", "confirmed"]
  }


  @doc false
  def changeset(tx, attrs) do
    tx
    |> cast(attrs, [:state, :txid, :rawtx, :channel, :tags, :data])
    |> cast_embed(:meta, with: &Meta.changeset/2)
    |> validate_required([:state, :txid, :channel])
    |> validate_format(:txid, ~r/^[a-f0-9]{64}$/i)
    |> validate_format(:channel, ~r/^\w[\w\-\/]*$/)
    |> validate_state
  end


  # TODO
  def transition_changeset(tx, "pushed", "confirmed", response) do
    block_height = get_in(response, [:payload, "block_height"])
    tx
    |> cast(%{block_height: block_height}, [:block_height])
  end


  # TODO
  defp validate_state(changeset) do
    transitions = __MODULE__.__fsmx__().__fsmx__(:transitions)

    validate_change(changeset, :state, fn :state, state ->
      case Map.keys(transitions) |> Enum.member?(state) do
        true -> []
        false -> [state: "cannot be #{state}"]
      end
    end)
  end

end
