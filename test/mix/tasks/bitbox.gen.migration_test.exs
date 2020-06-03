defmodule Mix.Tasks.Bitbox.Gen.MigrationTest do
  use ExUnit.Case, async: true
  import Mix.Tasks.Bitbox.Gen.Migration, only: [run: 1]
  import Bitbox.Test.FileHelpers

  @tmp_path Path.join(tmp_path(), inspect(Bitbox.Gen.Migration))
  @migrations_path Path.join(@tmp_path, "migrations")

  defmodule My.Repo do
    def __adapter__ do
      true
    end

    def config do
      [priv: Path.join("priv/tmp", inspect(Bitbox.Gen.Migration)), otp_app: :bitbox]
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
    assert String.match?(name, ~r/^\d{14}_setup_bitbox\.exs$/)
  end
end
