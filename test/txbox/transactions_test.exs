defmodule Txbox.TransactionsTest do
  use Txbox.Test.CaseTemplate
  alias Txbox.Transactions
  alias Txbox.Transactions.Tx


  def fixture(attrs \\ %{}) do
    txid = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    {:ok, tx} = attrs
    |> Map.put(:txid, txid)
    |> Transactions.create_tx
    tx
  end


  describe "get_tx/2" do
    setup do
      %{
        tx1: fixture(%{meta: %{title: "test1"}}),
        tx2: fixture(%{channel: "testing", meta: %{title: "test2"}})
      }
    end

    test "returns a tx", %{tx1: %{txid: txid}} do
      assert %Tx{} = tx = Transactions.get_tx(txid)
      assert tx.channel == "txbox"
      assert tx.meta.title == "test1"
    end

    test "returns a tx when querying by channel", %{tx2: %{txid: txid}} do
      assert %Tx{} = tx = Tx
      |> Transactions.channel("testing")
      |> Transactions.get_tx(txid)
      assert tx.channel == "testing"
      assert tx.meta.title == "test2"
    end

    test "returns nil when not found" do
      assert Transactions.get_tx("0000000000000000000000000000000000000000000000000000000000000000") == nil
    end
  end


  describe "list_tx/1" do
    setup do
      %{
        tx1: fixture(),
        tx2: fixture(%{channel: "testing"})
      }
    end

    test "returns all tx", ctx do
      txns = Transactions.list_tx()
      assert length(txns) == 2
      assert Enum.map(txns, & &1.txid) |> Enum.member?(ctx.tx1.txid)
      assert Enum.map(txns, & &1.txid) |> Enum.member?(ctx.tx2.txid)
    end

    test "returns tx filtered by channel", %{tx2: tx} do
      txns = Tx
      |> Transactions.channel("testing")
      |> Transactions.list_tx
      assert length(txns) == 1
      assert Enum.map(txns, & &1.txid) |> Enum.member?(tx.txid)
    end

    test "returns empty when none found" do
      assert [] = Tx
      |> Transactions.channel("foobar")
      |> Transactions.list_tx
    end
  end


  describe "create_tx/1" do
    test "returns Tx with valid attributes" do
      assert {:ok, %Tx{}} = Transactions.create_tx(%{txid: :crypto.strong_rand_bytes(32) |> Base.encode16})
    end

    test "returns Changeset with invalid attributes" do
      assert {:error, %Ecto.Changeset{}} = Transactions.create_tx(%{txid: "foobar"})
    end
  end


  describe "update_tx_status/2" do
    @describetag skip: "Skipping these tests whilst Transactions.update_tx_status/2 being refactored"
    setup do
      %{
        tx: fixture(),
        status: %{payload: %{foo: :bar}}
      }
    end

    test "returns Tx and updates mapi attributes with valid attributes", %{tx: tx, status: status} do
      assert {:ok, %Tx{} = tx} = Transactions.update_tx_status(tx, status)
      assert tx.mapi_attempt == 1
      assert tx.mapi_attempted_at != nil
      assert tx.mapi_completed_at == nil
      assert tx.status.payload == %{foo: :bar}
    end

    test "returns Tx and completes mapi status with correct attributes", %{tx: tx} do
      assert {:ok, %Tx{} = tx} = Transactions.update_tx_status(tx, %{payload: %{block_height: 100}})
      assert tx.mapi_completed_at != nil
    end

    test "updates the mapi_attempt count when nil given", %{tx: tx} do
      assert {:ok, %Tx{} = tx} = Transactions.update_tx_status(tx, nil)
      assert {:ok, %Tx{} = tx} = Transactions.update_tx_status(tx, nil)
      assert tx.mapi_attempt == 2
      assert tx.mapi_completed_at == nil
    end

    test "returns Changeset with invalid attributes", %{tx: tx} do
      assert {:error, %Ecto.Changeset{}} = Transactions.update_tx_status(tx, %{payload: ""})
    end
  end


  describe "delete_tx/1" do
    setup do
      %{tx: fixture()}
    end

    test "deletes the given tx", %{tx: tx} do
      assert {:ok, %Tx{}} = Transactions.delete_tx(tx)
      assert Transactions.get_tx(tx.txid) == nil
    end
  end


  describe "search_tx/2" do
    setup do
      %{
        tx1: fixture(%{meta: %{title: "One small step for man"}}),
        tx2: fixture(%{meta: %{title: "One giant leap for mankind"}}),
        tx3: fixture(%{meta: %{content: "History of mankind"}}),
        tx4: fixture(%{tags: ["history"]})
      }
    end

    test "searches meta content", ctx do
      [tx] = Tx |> Transactions.search_tx("one man")
      assert tx.txid == ctx.tx1.txid
    end

    test "searches meta content and tags", ctx do
      res = Tx |> Transactions.search_tx("history")
      assert length(res) == 2
      assert Enum.map(res, & &1.txid) |>  Enum.member?(ctx.tx3.txid)
      assert Enum.map(res, & &1.txid) |>  Enum.member?(ctx.tx4.txid)
    end
  end


  describe "channel/2" do
    setup do
      %{
        tx1: fixture(%{channel: "test1"}),
        tx2: fixture(%{channel: "test2"})
      }
    end

    test "returns tx from the specified channel", ctx do
      res = Tx
      |> Transactions.channel("test1")
      |> Transactions.list_tx
      assert Enum.map(res, & &1.txid) |>  Enum.member?(ctx.tx1.txid)
      refute Enum.map(res, & &1.txid) |>  Enum.member?(ctx.tx2.txid)
    end
  end


  describe "tagged/2" do
    setup do
      %{
        tx1: fixture(%{tags: ["foo", "bar", "bas"]}),
        tx2: fixture(%{tags: ["bar", "bas", "bish"]}),
        tx3: fixture(%{tags: ["bish"]}),
      }
    end

    test "returns tx with all matching tags", ctx do
      assert [tx] = Tx
      |> Transactions.tagged(["foo", "bar"])
      |> Transactions.list_tx
      assert tx.txid == ctx.tx1.txid

      assert res = Tx
      |> Transactions.tagged(["bar", "bas"])
      |> Transactions.list_tx
      assert length(res) == 2
      assert Enum.map(res, & &1.txid) |>  Enum.member?(ctx.tx1.txid)
      assert Enum.map(res, & &1.txid) |>  Enum.member?(ctx.tx2.txid)
    end
  end


  describe "confirmed/2" do
    @describetag skip: "Skipping these tests whilst Transactions.update_tx_status/2 being refactored"

    setup do
      {:ok, tx2} = fixture() |> Transactions.update_tx_status(%{payload: %{block_height: 9000}})
      %{tx1: fixture(), tx2: tx2}
    end

    test "returns confirmed transactions by default", %{tx2: tx} do
      txns = Tx
      |> Transactions.confirmed()
      |> Transactions.list_tx()
      assert Enum.map(txns, & &1.txid) |>  Enum.member?(tx.txid)
    end

    test "returns unconfirmed transactions when set to false", %{tx1: tx} do
      txns = Tx
      |> Transactions.confirmed(false)
      |> Transactions.list_tx()
      assert Enum.map(txns, & &1.txid) |>  Enum.member?(tx.txid)
    end
  end

end
