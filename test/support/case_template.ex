defmodule Bitbox.Test.CaseTemplate do
  @moduledoc false

  use ExUnit.CaseTemplate
  alias Bitbox.Test.Repo
  import Bitbox.Test.FileHelpers

  @tmp_dir Path.join(tmp_path(), "bitbox_test")

  using _opts do
    quote do
      import Bitbox.Test.CaseTemplate
      alias Bitbox.Test.Repo
    end
  end

  setup_all do
    on_exit(fn -> destroy_dir(@tmp_dir) end)
    :ok
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Bitbox.Test.Repo, {:shared, self()})
    :ok
  end

end
