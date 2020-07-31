defmodule Mix.Tasks.Txbox.Gen.MigrationsTest do
  use ExUnit.Case, async: true
  import Mix.Tasks.Txbox.Gen.Migrations, only: [run: 1]
  import Txbox.Test.FileHelpers

  @tmp_path Path.join(tmp_path(), inspect(Txbox.Gen.Migrations))
  @migrations_path Path.join(@tmp_path, "migrations")

  defmodule My.Repo do
    def __adapter__ do
      true
    end

    def config do
      [priv: Path.join("priv/tmp", inspect(Txbox.Gen.Migrations)), otp_app: :txbox]
    end
  end

  setup do
    create_dir(@migrations_path)
    on_exit(fn -> destroy_dir(@tmp_path) end)
    :ok
  end

  test "generates a new migration" do
    run(["-r", to_string(My.Repo)])
    files = File.ls!(@migrations_path)
    assert Enum.any?(files, & String.match?(&1, ~r/^\d{14}_setup_txbox\.exs$/))
    assert Enum.any?(files, & String.match?(&1, ~r/^\d{14}_create_txbox_mapi_responses\.exs$/))
  end
end
