defmodule Txbox.Transactions.Tx do
  use Ecto.Schema
  import Ecto.Changeset
  alias Txbox.Transactions.{Meta, Status}


  @typedoc "Txbox transaction struct"
  @type t :: %__MODULE__{
    id: String.t,
    txid: String.t
  }


  @default_channel "txbox"
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "txbox_txns" do
    field :txid, :string
    field :rawtx, :binary
    field :channel, :string, default: @default_channel
    field :tags, {:array, :string}
    field :data, :map
    field :block_hash, :string
    field :block_height, :integer

    field :mapi_attempt, :integer, default: 0
    field :mapi_attempted_at, :utc_datetime
    field :mapi_completed_at, :utc_datetime

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
    |> validate_format(:channel, ~r/^\w[\w\-\/]*$/)
  end


  def status_changeset(tx, attrs) do
    tx
    |> cast(%{status: attrs}, [])
    |> cast_embed(:status, with: &Status.changeset/2)
    |> put_block_height
    |> put_mapi_attempted
    |> put_mapi_completed
  end


  # TODO
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


  # TODO
  defp put_mapi_attempted(%{data: tx} = changeset) do
    now = DateTime.utc_now |> DateTime.truncate(:second)
    changeset
    |> put_change(:mapi_attempt, tx.mapi_attempt+1)
    |> put_change(:mapi_attempted_at, now)
  end


  # TODO
  defp put_mapi_completed(%{valid?: true, changes: %{block_height: i}} = changeset)
    when is_integer(i)
  do
    now = DateTime.utc_now |> DateTime.truncate(:second)
    changeset
    |> put_change(:mapi_completed_at, now)
  end

  defp put_mapi_completed(changeset), do: changeset

end
