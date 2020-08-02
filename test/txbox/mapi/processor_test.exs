defmodule Txbox.Mapi.ProcessorTest do
  use Txbox.Test.CaseTemplate
  alias Txbox.Transactions
  alias Txbox.Mapi.{Queue, Processor}


  def fixture(attrs \\ %{}) do
    txid = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    {:ok, tx} = attrs
    |> Map.put(:txid, txid)
    |> Transactions.create_tx
    tx
  end


  describe "mAPI push tx" do
    setup do
      {:ok, pid1} = Queue.start_link
      {:ok, pid2} = Processor.start_link
      :timer.sleep(1)
      tx1 = fixture(%{state: "pending", rawtx: <<1, 0, 0, 0, 0, 0, 0, 0, 0, 0>>})
      tx2 = fixture(%{state: "pending", rawtx: <<2, 0, 0, 0, 0, 0, 0, 0, 0, 0>>})

      Tesla.Mock.mock_global fn env ->
        cond do
          String.match?(env.body, ~r/01000000000000000000/) ->
            File.read!("test/mocks/mapi-push-success.json") |> Jason.decode! |> Tesla.Mock.json
          String.match?(env.body, ~r/02000000000000000000/) ->
            File.read!("test/mocks/mapi-push-failure.json") |> Jason.decode! |> Tesla.Mock.json
        end
      end

      %{pid1: pid1, pid2: pid2, tx1: tx1, tx2: tx2}
    end

    test "when mapi returns success, tx state should be pushed", ctx do
      Queue.push(ctx.tx1)
      :timer.sleep(100) # pause to allow the async http mock to return
      tx = Txbox.Transactions.get_tx(ctx.tx1.txid)
      assert tx.state == "pushed"
      assert is_map(tx.mapi_status)
      GenStage.stop(ctx.pid2)
      GenStage.stop(ctx.pid1)
    end

    test "when mapi returns failure, tx state should be failure", ctx do
      Queue.push(ctx.tx2)
      :timer.sleep(100) # pause to allow the async http mock to return
      tx = Txbox.Transactions.get_tx(ctx.tx2.txid)
      assert tx.state == "failed"
      assert is_map(tx.mapi_status)
      GenStage.stop(ctx.pid2)
      GenStage.stop(ctx.pid1)
    end
  end


  describe "mAPI status check " do
    setup do
      {:ok, pid1} = Queue.start_link
      {:ok, pid2} = Processor.start_link
      :timer.sleep(1)
      tx1 = fixture(%{state: "pushed"})
      tx2 = fixture(%{state: "pushed"})
      tx3 = fixture(%{state: "pushed"})

      Tesla.Mock.mock_global fn env ->
        cond do
          String.ends_with?(env.url, tx1.txid) ->
            File.read!("test/mocks/mapi-status-confirmed.json") |> Jason.decode! |> Tesla.Mock.json
          String.ends_with?(env.url, tx2.txid) ->
            File.read!("test/mocks/mapi-status-mempool.json") |> Jason.decode! |> Tesla.Mock.json
          String.ends_with?(env.url, tx3.txid) ->
            File.read!("test/mocks/mapi-status-notfound.json") |> Jason.decode! |> Tesla.Mock.json
        end
      end

      %{pid1: pid1, pid2: pid2, tx1: tx1, tx2: tx2, tx3: tx3}
    end

    test "when mapi returns tx as confirmed, tx state should be confirmed", ctx do
      Queue.push(ctx.tx1)
      :timer.sleep(100) # pause to allow the async http mock to return
      tx = Txbox.Transactions.get_tx(ctx.tx1.txid)
      assert tx.state == "confirmed"
      assert is_integer(tx.block_height)
      assert is_map(tx.mapi_status)
      GenStage.stop(ctx.pid2)
      GenStage.stop(ctx.pid1)
    end

    test "when mapi returns tx as mempool, tx state should be pushed", ctx do
      Queue.push(ctx.tx2)
      :timer.sleep(100) # pause to allow the async http mock to return
      tx = Txbox.Transactions.get_tx(ctx.tx2.txid)
      assert tx.state == "pushed"
      assert is_map(tx.mapi_status)
      GenStage.stop(ctx.pid2)
      GenStage.stop(ctx.pid1)
    end

    test "when mapi returns tx as not found, tx state should be pushed", ctx do
      Queue.push(ctx.tx3)
      :timer.sleep(100) # pause to allow the async http mock to return
      tx = Txbox.Transactions.get_tx(ctx.tx3.txid)
      assert tx.state == "pushed"
      assert is_map(tx.mapi_status)
      GenStage.stop(ctx.pid2)
      GenStage.stop(ctx.pid1)
    end
  end

end
