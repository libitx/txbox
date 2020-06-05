defmodule BitboxTest do
  use Bitbox.Test.CaseTemplate
  alias Bitbox.Transactions
  alias Bitbox.Transactions.Tx
  doctest Bitbox


  def fixture(attrs \\ %{}) do
    txid = :crypto.strong_rand_bytes(32) |> Base.encode16
    {:ok, tx} = attrs
    |> Map.put(:txid, txid)
    |> Transactions.create
    tx
  end


  setup do
    tx1 = fixture(%{meta: %{title: "test1"}, tags: ["foo"]})
    tx2 = fixture(%{channel: "test", meta: %{title: "test2"}, tags: ["foo", "bar", "baz"]})
    {:ok, tx3} = fixture(%{meta: %{title: "test3"}}) |> Transactions.update_status(%{payload: %{block_height: 1}})
    {:ok, tx4} = fixture(%{meta: %{title: "test4"}}) |> Transactions.update_status(%{payload: %{block_height: 2}})
    {:ok, tx5} = fixture(%{meta: %{title: "test5"}}) |> Transactions.update_status(%{payload: %{block_height: 3}})
    %{tx1: tx1, tx2: tx2, tx3: tx3, tx4: tx4, tx5: tx5}
  end


  describe "add/2" do
    test "add a tx to default channel" do
      txid = :crypto.strong_rand_bytes(32) |> Base.encode16
      assert {:ok, %Tx{} = tx} = Bitbox.add(%{txid: txid, meta: %{title: "test-a"}})
      assert tx.meta.title == "test-a"
      assert tx.channel == "bitbox"
    end

    test "add a tx to specific channel" do
      txid = :crypto.strong_rand_bytes(32) |> Base.encode16
      assert {:ok, %Tx{} = tx} = Bitbox.add("test", %{txid: txid, meta: %{title: "test-b"}})
      assert tx.meta.title == "test-b"
      assert tx.channel == "test"
    end

    test "returns error with invalid attributes" do
      assert {:error, %{errors: errors}} = Bitbox.add(%{})
      assert Keyword.keys(errors) |> Enum.member?(:txid)
    end
  end


  describe "get/2" do
    test "get a tx in default channel", %{tx1: tx} do
      assert {:ok, %Tx{channel: "bitbox"} = tx} = Bitbox.get(tx.txid)
      assert tx.meta.title == "test1"
    end

    test "get a tx scoped by channel", %{tx2: tx} do
      assert {:ok, %Tx{channel: "test"} = tx} = Bitbox.get("test", tx.txid)
      assert tx.meta.title == "test2"
    end

    test "wont find the tx in incorrect channel", %{tx1: tx} do
      assert {:error, :not_found} = Bitbox.get("test", tx.txid)
    end

    test "find the tx with global channel scope", %{tx2: tx} do
      assert {:ok, %Tx{channel: "test"} = tx} = Bitbox.get("_", tx.txid)
    end

    test "wont find the tx in doesnt exist" do
      assert {:error, :not_found} = Bitbox.get("_", "abcdef")
    end
  end


  describe "all/2" do
    test "get all tx in default channel" do
      assert {:ok, txns} = Bitbox.all()
      assert length(txns) == 4
    end

    test "get all tx in specific channel" do
      assert {:ok, txns} = Bitbox.all("test")
      assert length(txns) == 1
    end

    test "get all tx with global channel scope" do
      assert {:ok, txns} = Bitbox.all("_")
      assert length(txns) == 5
    end

    test "get all tx with matching tags" do
      assert {:ok, txns} = Bitbox.all("_", %{tagged: "foo"})
      assert length(txns) == 2
    end

    test "get all tx with matching tags as array" do
      assert {:ok, txns} = Bitbox.all("_", %{tagged: ["foo", "bar"]})
      assert length(txns) == 1
    end

    test "get all tx with matching tags as comma seperated list" do
      assert {:ok, txns} = Bitbox.all("_", %{tagged: "bar, baz"})
      assert length(txns) == 1
    end

    test "get all tx from specific height" do
      assert {:ok, txns} = Bitbox.all(%{from: 2})
      assert length(txns) == 2
      assert {:ok, txns} = Bitbox.all(%{from: 3})
      assert length(txns) == 1
    end

    test "get all tx to specific height" do
      assert {:ok, txns} = Bitbox.all(%{to: 2})
      assert length(txns) == 2
      assert {:ok, txns} = Bitbox.all(%{to: 3})
      assert length(txns) == 3
    end

    test "get all tx at specific height" do
      assert {:ok, txns} = Bitbox.all(%{at: 2})
      assert length(txns) == 1
    end

    test "get all unconfirmed tx" do
      assert {:ok, txns} = Bitbox.all("_", %{at: "null"})
      assert length(txns) == 2
    end

    test "get all confirmed tx" do
      assert {:ok, txns} = Bitbox.all(%{at: "-null"})
      assert length(txns) == 3
    end

    test "get tx sorted by block height" do
      assert {:ok, [tx]} = Bitbox.all(%{at: true, order: "i", limit: 1})
      assert tx.meta.title == "test3"
      assert {:ok, [tx]} = Bitbox.all(%{at: true, order: "-i", limit: 1})
      assert tx.meta.title == "test5"
    end

    test "get tx paged and offset" do
      assert {:ok, txns} = Bitbox.all(%{at: true, order: "i", limit: 2})
      assert length(txns) == 2
      assert {:ok, [tx]} = Bitbox.all(%{at: true, order: "i", limit: 2, offset: 2})
      assert tx.meta.title == "test5"
    end

  end
end
