defmodule Txbox.TransactionsTest do
  use Txbox.Test.CaseTemplate
  alias Txbox.Transactions
  alias Txbox.Transactions.{Tx, MapiResponse}


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


  describe "update_tx/2" do
    setup do
      %{
        tx1: fixture(%{data: %{foo: "bar"}}),
        tx2: fixture(%{state: "queued", data: %{foo: "bar"}})
      }
    end

    test "returns updated Tx with valid attributes", ctx do
      {:ok, %Tx{} = tx} = Transactions.update_tx(ctx.tx1, %{channel: "foobar", data: %{qux: "baz"}})
      assert tx.channel == "foobar"
      assert tx.data == %{qux: "baz"}
    end

    test "returns Changeset if mutating non-pending transaction", ctx do
      assert {:error, %Ecto.Changeset{}} = Transactions.update_tx(ctx.tx2, %{data: %{qux: "baz"}})
    end

    test "returns Changeset with invalid attributes", ctx do
      assert {:error, %Ecto.Changeset{}} = Transactions.update_tx(ctx.tx1, %{txid: "foobar"})
    end
  end

  describe "update_tx_state/2" do
    setup do
      %{tx: fixture()}
    end

    test "returns updated Tx with allowed state change", ctx do
      assert {:ok, %Tx{state: "pushed"}} = Transactions.update_tx_state(ctx.tx, "pushed")
    end

    test "returns Changeset if try to set invalid state", ctx do
      assert {:error, %Ecto.Changeset{}} = Transactions.update_tx_state(ctx.tx, "confirmed")
    end
  end

  describe "update_tx_state/3" do
    setup do
      %{
        tx1: fixture(),
        tx2: fixture(%{state: "queued"}),
        tx3: fixture(%{state: "pushed"}),
        status: %{payload: %{foo: :bar}}
      }
    end

    test "returns updated Tx with allowed state change and valid status attributes", ctx do
      assert {:ok, %Tx{} = tx} = Transactions.update_tx_state(ctx.tx2, "pushed", ctx.status)
      assert tx.state == "pushed"
      assert tx.status.payload == %{"foo" => "bar"}
    end

    test "returns Changeset with invalid state change", ctx do
      assert {:error, %{tx: %Ecto.Changeset{}}} = Transactions.update_tx_state(ctx.tx1, "confirmed", ctx.status)
    end

    test "returns Changeset with invalid status attributes", %{tx2: tx} do
      assert {:error, %{mapi_response: %Ecto.Changeset{}}} = Transactions.update_tx_state(tx, "pushed", %{payload: ""})
    end

    test "always returns the most resent mapi response", %{tx3: tx} do
      assert {:ok, %Tx{} = tx} = Transactions.update_tx_state(tx, "pushed", %{payload: %{i: 1}})
      :timer.sleep(1) # pause to ensure inserted_at timestamp increments by nanosecond
      assert {:ok, %Tx{} = tx} = Transactions.update_tx_state(tx, "pushed", %{payload: %{i: 2}})
      :timer.sleep(1) # pause to ensure inserted_at timestamp increments by nanosecond
      assert {:ok, %Tx{} = tx} = Transactions.update_tx_state(tx, "confirmed", %{payload: %{i: 3}})
      assert tx.state == "confirmed"
      assert tx.status.payload == %{"i" => 3}
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


  describe "list_tx_for_mapi/0" do
    setup do
      mapi = %{payload: %{foo: :bar}}
      tx1 = fixture(%{state: "pending", data: %{n: "tx1"}})
      tx2 = fixture(%{state: "queued", data: %{n: "tx2"}})
      {:ok, tx3} = fixture(%{state: "queued", data: %{n: "tx3"}}) |> Transactions.update_tx_state("failed", mapi)
      tx4 = fixture(%{state: "pushed", data: %{n: "tx4"}})
      {:ok, tx5} = fixture(%{state: "pushed", data: %{n: "tx5"}}) |> Transactions.update_tx_state("pushed", mapi)
      {:ok, tx6} = fixture(%{state: "pushed", data: %{n: "tx6"}}) |> Transactions.update_tx_state("confirmed", mapi)
      tx7 = Enum.reduce(1..20, fixture(%{state: "pushed", data: %{n: "tx7"}}), fn _n, tx ->
        case Transactions.update_tx_state(tx, "pushed", mapi) do
          {:ok, tx} -> tx
          {:error, error} -> raise error
        end
      end)

      %{tx1: tx1, tx2: tx2, tx3: tx3, tx4: tx4, tx5: tx5, tx6: tx6, tx7: tx7}
    end

    test "returns the correct transactions according the the rules", ctx do
      txns = Transactions.list_tx_for_mapi()
      txids = Enum.map(txns, & &1.txid)
      refute Enum.member?(txids, ctx.tx1.txid)
      assert Enum.member?(txids, ctx.tx2.txid)
      refute Enum.member?(txids, ctx.tx3.txid)
      assert Enum.member?(txids, ctx.tx4.txid)
      refute Enum.member?(txids, ctx.tx5.txid)
      refute Enum.member?(txids, ctx.tx6.txid)
      refute Enum.member?(txids, ctx.tx7.txid)
    end

    test "includes tx if last status is over 5 mintutes ago", ctx do
      datetime = DateTime.now!("Etc/UTC") |> DateTime.add(-600)
      Transactions.repo().update_all(MapiResponse, set: [inserted_at: datetime])
      txns = Transactions.list_tx_for_mapi()
      txids = Enum.map(txns, & &1.txid)
      assert Enum.member?(txids, ctx.tx5.txid)
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
    setup do
      {:ok, tx2} = fixture(%{state: "pushed"}) |> Transactions.update_tx_state("confirmed", %{payload: %{"block_height" => 9000}})
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


  describe "with_rawtx/1" do
    setup do
      %{
        tx1: fixture(%{rawtx: <<1,0,0,0,0,0,0,0,0,0>>}),
        tx2: fixture(%{rawtx: <<1,0,0,0,0,0,0,0,0,0>>})
      }
    end

    test "and raw_tx/1 by default does not select the rawtx", %{tx1: %{txid: txid}} do
      assert %Tx{} = tx = Transactions.get_tx(txid)
      assert is_nil(tx.rawtx)
    end

    test "and get_tx/1 selects rawtx", %{tx1: %{txid: txid}} do
      assert %Tx{} = tx = Tx
      |> Transactions.with_rawtx()
      |> Transactions.get_tx(txid)
      refute is_nil(tx.rawtx)
    end

    test "and list_tx/1 by default does not select the rawtx" do
      txns = Transactions.list_tx()
      assert Enum.all?(txns, & is_nil(&1.rawtx))
    end

    test "and list_tx/1 selects rawtx" do
      txns = Tx
      |> Transactions.with_rawtx()
      |> Transactions.list_tx()
      refute Enum.any?(txns, & is_nil(&1.rawtx))
    end

  end

end
