defmodule Txbox.Test.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :txbox,
    adapter: Ecto.Adapters.Postgres

end
