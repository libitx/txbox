defmodule Txbox.Transactions.Meta do
  @moduledoc """
  Transaction metadata embedded schema module.

  The transaction metadata is a structured schema for describing human readable
  metadata about the transaction. The following attributes can be set:

  * `:title` - The title of the transaction.
  * `:description` - A short description of the transaction.
  * `:image` - The url of an approriate preview image for the transaction.
  * `:link` - The full permalink URL to access the transaction.
  * `:content` - Markdown formatted content of the transaction.
  """
  use Ecto.Schema
  import Ecto.Changeset


  @typedoc "Transaction metadata schema"
  @type t :: %__MODULE__{
    title: String.t,
    description: String.t,
    image: String.t,
    link: String.t,
    content: String.t
  }


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
