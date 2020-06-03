defmodule Bitbox.Transactions.Status do
  use Ecto.Schema
  import Ecto.Changeset


  embedded_schema do
    field :title

  end


  @doc false
  def changeset(meta, attrs) do
    meta
    |> cast(attrs, [:title])
  end

end
