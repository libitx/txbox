defmodule Bitbox.TxStatusTest do
  use Bitbox.Test.CaseTemplate
  import ExUnit.CaptureLog
  alias Bitbox.Transactions
  alias Bitbox.TxStatus.{Queue, Processor}


  def fixture(attrs \\ %{}) do
    txid = :crypto.strong_rand_bytes(32) |> Base.encode16
    {:ok, tx} = attrs
    |> Map.put(:txid, txid)
    |> Transactions.create
    tx
  end


  describe "Bitbox.TxStatus.Queue" do
    setup do
      %{tx1: fixture(), tx2: fixture()}
    end

    test "contains a FIFO queue of txids with attempts count", ctx do
      {:ok, pid} = Queue.start_link
      Queue.push(ctx.tx1)
      Queue.push(ctx.tx2.txid)
      stream = GenStage.stream([{Queue, max_demand: 1}])
      assert [{txid, 0}] = Enum.take(stream, 1)
      assert txid == ctx.tx1.txid
      assert [{txid, 0}] = Enum.take(stream, 1)
      assert txid == ctx.tx2.txid
      GenStage.stop(pid)
    end
  end


  describe "Bitbox.TxStatus.Processor with confirmed tx" do
    setup do
      Tesla.Mock.mock_global fn _env ->
        File.read!("test/mocks/tx-status.json") |> Jason.decode! |> Tesla.Mock.json
      end
      :ok
    end

    test "processes a tx and updates the status" do
      {:ok, pid1} = Queue.start_link
      {:ok, pid2} = Processor.start_link
      tx = fixture()
      Queue.push(tx)
      Process.sleep(50) # quick sleep to allow the async http mock to return
      tx = Bitbox.Transactions.get(tx.txid)
      assert tx.status && is_integer(tx.status.i)
      GenStage.stop(pid2)
      GenStage.stop(pid1)
    end

    test "unknown tx logs an error" do
      {:ok, pid1} = Queue.start_link
      {:ok, pid2} = Processor.start_link
      assert capture_log(fn ->
        Queue.push("0000000000000000")
        Process.sleep(50) # quick sleep to allow the async http mock to return
      end) =~ "TX not found"
      GenStage.stop(pid2)
      GenStage.stop(pid1)
    end
  end
end