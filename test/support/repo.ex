defmodule Bitbox.Test.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :bitbox,
    adapter: Ecto.Adapters.Postgres

end
