defmodule Txbox.Test.CaseTemplate do
  @moduledoc false

  use ExUnit.CaseTemplate
  alias Txbox.Test.Repo
  import Txbox.Test.FileHelpers

  @tmp_dir Path.join(tmp_path(), "txbox_test")

  using _opts do
    quote do
      import Txbox.Test.CaseTemplate
      alias Txbox.Test.Repo
    end
  end

  setup_all do
    on_exit(fn -> destroy_dir(@tmp_dir) end)
    :ok
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Txbox.Test.Repo, {:shared, self()})
    :ok
  end

end
