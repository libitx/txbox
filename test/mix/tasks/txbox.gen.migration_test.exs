defmodule Mix.Tasks.Txbox.Gen.MigrationTest do
  use ExUnit.Case, async: true
  import Mix.Tasks.Txbox.Gen.Migration, only: [run: 1]
  import Txbox.Test.FileHelpers

  @tmp_path Path.join(tmp_path(), inspect(Txbox.Gen.Migration))
  @migrations_path Path.join(@tmp_path, "migrations")

  defmodule My.Repo do
    def __adapter__ do
      true
    end

    def config do
      [priv: Path.join("priv/tmp", inspect(Txbox.Gen.Migration)), otp_app: :txbox]
    end
  end

  setup do
    create_dir(@migrations_path)
    on_exit(fn -> destroy_dir(@tmp_path) end)
    :ok
  end

  test "generates a new migration" do
    run(["-r", to_string(My.Repo)])
    assert [name] = File.ls!(@migrations_path)
    assert String.match?(name, ~r/^\d{14}_setup_txbox\.exs$/)
  end
end
