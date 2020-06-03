defmodule Bitbox.Transactions.Status do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key false

  embedded_schema do
    field :payload, :map
    field :public_key, :string
    field :signature, :string
    field :verified, :boolean, default: false
    field :confirmed, :boolean, default: false
  end


  @doc false
  def changeset(meta, attrs) do
    meta
    |> cast(attrs, [:payload, :public_key, :signature, :verified, :confirmed])
    |> validate_required([:payload])
  end

end
