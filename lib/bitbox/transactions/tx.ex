defmodule Bitbox.Transactions.Tx do
  use Ecto.Schema
  import Ecto.Changeset
  alias Bitbox.Transactions.{Meta, Status}


  @primary_key {:txid, :string, autogenerate: false}
  @foreign_key_type :string


  schema "bitbox_txns" do
    field :rawtx, :binary
    field :channel, :string, default: "/bitbox"
    field :tags, {:array, :string}
    field :data, :map

    embeds_one :meta, Meta
    embeds_one :status, Status

    timestamps()
  end


  @doc false
  def changeset(tx, attrs) do
    tx
    |> cast(attrs, [:txid, :rawtx, :channel, :tags, :data])
    |> cast_embed(:meta, with: &Meta.changeset/2)
    |> validate_required([:txid, :channel])
    |> validate_format(:txid, ~r/^[a-f0-9]{64}$/i)
    |> validate_format(:channel, ~r/^\/[\w\-\/]+$/)
  end


  def status_changeset(tx, attrs) do
    tx
    |> cast(attrs, [])
    |> cast_embed(:status, with: &Status.changeset/2)
  end

end
