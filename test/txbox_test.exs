defmodule TxboxTest do
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


  describe "add/2" do
    test "add a tx to default channel" do
      txid = :crypto.strong_rand_bytes(32) |> Base.encode16
      assert {:ok, %Tx{} = tx} = Txbox.add(%{txid: txid, meta: %{title: "test-a"}})
      assert tx.meta.title == "test-a"
      assert tx.channel == "txbox"
    end

    test "add a tx to specific channel" do
      txid = :crypto.strong_rand_bytes(32) |> Base.encode16
      assert {:ok, %Tx{} = tx} = Txbox.add("test", %{txid: txid, meta: %{title: "test-b"}})
      assert tx.meta.title == "test-b"
      assert tx.channel == "test"
    end

    test "returns error with invalid attributes" do
      assert {:error, %{errors: errors}} = Txbox.add(%{})
      assert Keyword.keys(errors) |> Enum.member?(:txid)
    end
  end


  describe "find/2" do
    setup do
      tx1 = fixture(%{meta: %{title: "test1"}, tags: ["foo"]})
      tx2 = fixture(%{channel: "test", meta: %{title: "test2"}, tags: ["foo", "bar", "baz"]})
      %{tx1: tx1, tx2: tx2}
    end

    test "get a tx in default channel", %{tx1: tx} do
      assert {:ok, %Tx{channel: "txbox"} = tx} = Txbox.find(tx.txid)
      assert tx.meta.title == "test1"
    end

    test "get a tx scoped by channel", %{tx2: tx} do
      assert {:ok, %Tx{channel: "test"} = tx} = Txbox.find("test", tx.txid)
      assert tx.meta.title == "test2"
    end

    test "wont find the tx in incorrect channel", %{tx1: tx} do
      assert {:error, :not_found} = Txbox.find("test", tx.txid)
    end

    test "find the tx with global channel scope", %{tx2: tx} do
      assert {:ok, %Tx{channel: "test"} = tx} = Txbox.find("_", tx.txid)
    end

    test "wont find the tx in doesnt exist" do
      assert {:error, :not_found} = Txbox.find("_", "0000000000000000000000000000000000000000000000000000000000000000")
    end
  end


  describe "find_all/2" do
    setup do
      tx1 = fixture(%{meta: %{title: "test1"}, tags: ["foo"]})
      tx2 = fixture(%{channel: "test", meta: %{title: "test2"}, tags: ["foo", "bar", "baz"]})
      {:ok, tx3} = fixture(%{meta: %{title: "test3"}}) |> Transactions.update_tx_status(%{payload: %{block_height: 1}})
      {:ok, tx4} = fixture(%{meta: %{title: "test4"}}) |> Transactions.update_tx_status(%{payload: %{block_height: 2}})
      {:ok, tx5} = fixture(%{meta: %{title: "test5"}}) |> Transactions.update_tx_status(%{payload: %{block_height: 3}})
      %{tx1: tx1, tx2: tx2, tx3: tx3, tx4: tx4, tx5: tx5}
    end

    test "get all tx in default channel" do
      assert {:ok, txns} = Txbox.find_all()
      assert length(txns) == 4
    end

    test "get all tx in specific channel" do
      assert {:ok, txns} = Txbox.find_all("test")
      assert length(txns) == 1
    end

    test "get all tx with global channel scope" do
      assert {:ok, txns} = Txbox.find_all("_")
      assert length(txns) == 5
    end

    test "get all tx with matching tags" do
      assert {:ok, txns} = Txbox.find_all("_", %{tagged: "foo"})
      assert length(txns) == 2
    end

    test "get all tx with matching tags as array" do
      assert {:ok, txns} = Txbox.find_all("_", %{tagged: ["foo", "bar"]})
      assert length(txns) == 1
    end

    test "get all tx with matching tags as comma seperated list" do
      assert {:ok, txns} = Txbox.find_all("_", %{tagged: "bar, baz"})
      assert length(txns) == 1
    end

    test "get all tx from specific height" do
      assert {:ok, txns} = Txbox.find_all(%{from: 2})
      assert length(txns) == 2
      assert {:ok, txns} = Txbox.find_all(%{from: 3})
      assert length(txns) == 1
    end

    test "get all tx to specific height" do
      assert {:ok, txns} = Txbox.find_all(%{to: 2})
      assert length(txns) == 2
      assert {:ok, txns} = Txbox.find_all(%{to: 3})
      assert length(txns) == 3
    end

    test "get all tx at specific height" do
      assert {:ok, txns} = Txbox.find_all(%{at: 2})
      assert length(txns) == 1
    end

    test "get all unconfirmed tx" do
      assert {:ok, txns} = Txbox.find_all("_", %{at: "null"})
      assert length(txns) == 2
    end

    test "get all confirmed tx" do
      assert {:ok, txns} = Txbox.find_all(%{at: "-null"})
      assert length(txns) == 3
    end

    test "get tx sorted by block height" do
      assert {:ok, [tx]} = Txbox.find_all(%{at: true, order: "i", limit: 1})
      assert tx.meta.title == "test3"
      assert {:ok, [tx]} = Txbox.find_all(%{at: true, order: "-i", limit: 1})
      assert tx.meta.title == "test5"
    end

    test "get tx paged and offset" do
      assert {:ok, txns} = Txbox.find_all(%{at: true, order: "i", limit: 2})
      assert length(txns) == 2
      assert {:ok, [tx]} = Txbox.find_all(%{at: true, order: "i", limit: 2, offset: 2})
      assert tx.meta.title == "test5"
    end
  end


  describe "search/2" do
    setup do
      tx1 = fixture(%{meta: %{title: "Hubble Ultra-Deep Field"}, tags: ["photos"]})
      tx2 = fixture(%{channel: "test", meta: %{title: "Bitcoin: A Peer-to-Peer Electronic Cash System"}, tags: ["bsv"]})
      %{tx1: tx1, tx2: tx2}
    end

    test "get all tx by the search term" do
      assert {:ok, [tx]} = Txbox.search("hubble photos")
      assert tx.meta.title == "Hubble Ultra-Deep Field"
      assert {:ok, []} = Txbox.search("bitcoin bsv")
    end


    test "get all tx by the search term scoped by channel" do
      assert {:ok, [tx]} = Txbox.search("test", "bitcoin bsv")
      assert tx.meta.title == "Bitcoin: A Peer-to-Peer Electronic Cash System"
      assert {:ok, []} = Txbox.search("test", "hubble photos")
    end
  end

end