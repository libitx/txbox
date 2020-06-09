defmodule Txbox.Transactions.Status do
  @moduledoc """
  Miner status embedded schema module.

  When a new new transaction is added, Txbox automatically syncs with the
  configured miner's Mercant API and caches the status of the transaction. This
  means your transaction always has a signed payload from a miner, confirming
  when the transaction was mined, the block height and hash.

  Forr details, refer to the `t:Manic.JSONEnvelope.payload/0`.
  """
  use Ecto.Schema
  import Ecto.Changeset


  @typedoc "Miner status schema"
  @type t :: %__MODULE__{
    payload: Manic.JSONEnvelope.payload,
    public_key: String.t,
    signature: String.t,
    verified: boolean
  }


  @primary_key false

  embedded_schema do
    field :payload, :map
    field :public_key, :string
    field :signature, :string
    field :verified, :boolean, default: false
  end


  @doc false
  def changeset(meta, attrs) do
    meta
    |> cast(attrs, [:payload, :public_key, :signature, :verified])
    |> validate_required([:payload])
  end

end
