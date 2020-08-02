defmodule Txbox.Mapi.StatusTest do
  use Txbox.Test.CaseTemplate
  alias Txbox.Transactions
  alias Txbox.Transactions.Tx
  alias Txbox.Mapi.Queue


  def fixture(attrs \\ %{}) do
    txid = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    {:ok, tx} = attrs
    |> Map.put(:txid, txid)
    |> Transactions.create_tx
    tx
  end


  describe "Queue startup" do
    setup do
      tx1 = fixture()
      tx2 = fixture(%{state: "pending"})
      :timer.sleep(1) # pause to ensure inserted_at timestamp increments
      tx3 = fixture(%{state: "pushed"})
      tx4 = fixture(%{state: "pushed"}) |> Transactions.update_tx_state("confirmed", %{payload: %{"block_height" => 9000}})
      {:ok, pid} = Queue.start_link
      %{pid: pid, tx1: tx1, tx2: tx2, tx3: tx3, tx4: tx4}
    end

    test "automatically loads existing pending and pushed txns", ctx do
      stream = GenStage.stream([{Queue, max_demand: 1}])
      assert [%Tx{} = tx] = Enum.take(stream, 1)
      assert tx.txid == ctx.tx2.txid
      assert [%Tx{} = tx] = Enum.take(stream, 1)
      assert tx.txid == ctx.tx3.txid
      GenStage.stop(ctx.pid)
    end
  end


  describe "Queue FIFO" do
    setup do
      {:ok, pid} = Queue.start_link
      tx1 = fixture(%{state: "pending"})
      tx2 = fixture(%{state: "pushed"})
      %{pid: pid, tx1: tx1, tx2: tx2}
    end

    test "txns emitted in order of entry", ctx do
      Queue.push(ctx.tx1)
      Queue.push(ctx.tx2)
      stream = GenStage.stream([{Queue, max_demand: 1}])
      assert [%Tx{} = tx] = Enum.take(stream, 1)
      assert tx.txid == ctx.tx1.txid
      assert [%Tx{} = tx] = Enum.take(stream, 1)
      assert tx.txid == ctx.tx2.txid
      GenStage.stop(ctx.pid)
    end
  end

end
