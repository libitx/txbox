defmodule Bitbox.Transactions.Meta do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key false
  
  embedded_schema do
    field :title
    field :description
    field :image
    field :link
    field :content
  end


  @doc false
  def changeset(meta, attrs) do
    meta
    |> cast(attrs, [:title, :description, :image, :link, :content])
  end

end
