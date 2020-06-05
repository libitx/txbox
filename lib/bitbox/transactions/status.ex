defmodule Bitbox.Transactions.Status do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key false

  embedded_schema do
    field :payload, :map
    field :public_key, :string
    field :signature, :string
    field :verified, :boolean, default: false
    field :i, :integer
  end


  @doc false
  def changeset(meta, attrs) do
    meta
    |> cast(attrs, [:payload, :public_key, :signature, :verified])
    |> validate_required([:payload])
    |> put_block_height
  end


  # TODO
  defp put_block_height(%{valid?: true, changes: %{payload: payload}} = changeset) do
    i = payload[:block_height] || payload["block_height"]
    put_change(changeset, :i, i)
  end

  defp put_block_height(changeset), do: changeset


end
