defmodule Txbox.Transactions.MapiResponse do
  @moduledoc """
  TODO
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Txbox.Transactions.Tx


  @typedoc "MAPI Response schema"
  @type t :: %__MODULE__{
    id: binary,
    type: String.t,
    payload: Manic.JSONEnvelope.payload,
    public_key: String.t,
    signature: String.t,
    verified: boolean,
    tx_guid: binary
  }


  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "txbox_mapi_responses" do
    field :type, :string
    field :payload, :map
    field :public_key, :string
    field :signature, :string
    field :verified, :boolean, default: false

    belongs_to :tx, Tx, foreign_key: :tx_guid, references: :guid

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end


  @doc false
  def changeset(response, attrs) do
    response
    |> cast(attrs, [:type, :payload, :public_key, :signature, :verified])
    |> validate_required([:type, :payload])
    |> validate_inclusion(:type, ["push", "status"])
  end

  def push_changeset(response, attrs) do
    response
    |> change(%{type: "push"})
    |> changeset(attrs)
  end

  def status_changeset(response, attrs) do
    response
    |> change(%{type: "status"})
    |> changeset(attrs)
  end

end
