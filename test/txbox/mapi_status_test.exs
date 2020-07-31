#defmodule Txbox.MapiStatusTest do
#  use Txbox.Test.CaseTemplate
#  alias Txbox.Transactions
#  alias Txbox.Transactions.Tx
#  alias Txbox.MapiStatus.{Queue, Processor}
#
#
#  def fixture(attrs \\ %{}) do
#    txid = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
#    {:ok, tx} = attrs
#    |> Map.put(:txid, txid)
#    |> Transactions.create_tx
#    tx
#  end
#
#
#  describe "Txbox.MapiStatus.Queue" do
#    setup do
#      {:ok, pid} = Queue.start_link
#      %{pid: pid, tx1: fixture(), tx2: fixture()}
#    end
#
#    test "contains a FIFO queue of txids with attempts count", ctx do
#      Queue.push(ctx.tx1)
#      Queue.push(ctx.tx2)
#      stream = GenStage.stream([{Queue, max_demand: 1}])
#      assert [%Tx{txid: txid}] = Enum.take(stream, 1)
#      assert txid == ctx.tx1.txid
#      assert [%Tx{txid: txid}] = Enum.take(stream, 1)
#      assert txid == ctx.tx2.txid
#      GenStage.stop(ctx.pid)
#    end
#  end
#
#
#  describe "Txbox.MapiStatus.Processor with confirmed tx" do
#    setup do
#      Tesla.Mock.mock_global fn _env ->
#        File.read!("test/mocks/tx-status.json") |> Jason.decode! |> Tesla.Mock.json
#      end
#      :ok
#    end
#
#    test "processes a tx and updates the status" do
#      {:ok, pid1} = Queue.start_link
#      {:ok, pid2} = Processor.start_link
#      tx = fixture()
#      Queue.push(tx)
#      Process.sleep(50) # quick sleep to allow the async http mock to return
#      tx = Txbox.Transactions.get_tx(tx.txid)
#      assert is_integer(tx.block_height)
#      GenStage.stop(pid2)
#      GenStage.stop(pid1)
#    end
#  end
#end
