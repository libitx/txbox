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


  describe "all/2" do
    setup do
      tx1 = fixture(%{rawtx: <<1,0,0,0,0,0,0,0,0,0>>, meta: %{title: "test1"}, tags: ["foo"]})
      tx2 = fixture(%{channel: "test", meta: %{title: "test2"}, tags: ["foo", "bar", "baz"]})
      {:ok, tx3} = fixture(%{state: "pushed", meta: %{title: "test3"}}) |> Transactions.update_tx_state("confirmed", %{payload: %{"block_height" => 1}})
      {:ok, tx4} = fixture(%{state: "pushed", meta: %{title: "test4"}}) |> Transactions.update_tx_state("confirmed", %{payload: %{"block_height" => 2}})
      {:ok, tx5} = fixture(%{state: "pushed", meta: %{title: "test5"}}) |> Transactions.update_tx_state("confirmed", %{payload: %{"block_height" => 3}})
      %{tx1: tx1, tx2: tx2, tx3: tx3, tx4: tx4, tx5: tx5}
    end

    test "get all tx in default channel" do
      assert {:ok, txns} = Txbox.all()
      assert length(txns) == 4
    end

    test "get all tx in specific channel" do
      assert {:ok, txns} = Txbox.all("test")
      assert length(txns) == 1
    end

    test "get all tx with global channel scope" do
      assert {:ok, txns} = Txbox.all("_")
      assert length(txns) == 5
      assert Enum.all?(txns, & is_nil(&1.rawtx))
    end

    test "get all tx with rawtx selected" do
      assert {:ok, txns} = Txbox.all("_", %{rawtx: true})
      assert length(txns) == 5
      refute Enum.all?(txns, & is_nil(&1.rawtx))
    end

    test "get all tx with matching tags" do
      assert {:ok, txns} = Txbox.all("_", %{tagged: "foo"})
      assert length(txns) == 2
    end

    test "get all tx with matching tags as array" do
      assert {:ok, txns} = Txbox.all("_", %{tagged: ["foo", "bar"]})
      assert length(txns) == 1
    end

    test "get all tx with matching tags as comma seperated list" do
      assert {:ok, txns} = Txbox.all("_", %{tagged: "bar, baz"})
      assert length(txns) == 1
    end

    test "get all tx from specific height" do
      assert {:ok, txns} = Txbox.all(%{from: 2})
      assert length(txns) == 2
      assert {:ok, txns} = Txbox.all(%{from: 3})
      assert length(txns) == 1
    end

    test "get all tx to specific height" do
      assert {:ok, txns} = Txbox.all(%{to: 2})
      assert length(txns) == 2
      assert {:ok, txns} = Txbox.all(%{to: 3})
      assert length(txns) == 3
    end

    test "get all tx at specific height" do
      assert {:ok, txns} = Txbox.all(%{at: 2})
      assert length(txns) == 1
    end

    test "get all unconfirmed tx" do
      assert {:ok, txns} = Txbox.all("_", %{at: "null"})
      assert length(txns) == 2
    end

    test "get all confirmed tx" do
      assert {:ok, txns} = Txbox.all(%{at: "-null"})
      assert length(txns) == 3
    end

    test "get tx sorted by block height" do
      assert {:ok, [tx]} = Txbox.all(%{at: true, order: "i", limit: 1})
      assert tx.meta.title == "test3"
      assert {:ok, [tx]} = Txbox.all(%{at: true, order: "-i", limit: 1})
      assert tx.meta.title == "test5"
    end

    test "get tx paged and offset" do
      assert {:ok, txns} = Txbox.all(%{at: true, order: "i", limit: 2})
      assert length(txns) == 2
      assert {:ok, [tx]} = Txbox.all(%{at: true, order: "i", limit: 2, offset: 2})
      assert tx.meta.title == "test5"
    end
  end


  describe "all/2 searching" do
    setup do
      tx1 = fixture(%{meta: %{title: "Hubble Ultra-Deep Field"}, tags: ["photos"]})
      tx2 = fixture(%{channel: "test", meta: %{title: "Bitcoin: A Peer-to-Peer Electronic Cash System"}, tags: ["bsv"]})
      %{tx1: tx1, tx2: tx2}
    end

    test "get all tx by the search term" do
      assert {:ok, [tx]} = Txbox.all(%{search: "hubble photos"})
      assert tx.meta.title == "Hubble Ultra-Deep Field"
      assert {:ok, []} = Txbox.all(%{search: "bitcoin bsv"})
    end


    test "get all tx by the search term scoped by channel" do
      assert {:ok, [tx]} = Txbox.all("test", %{search: "bitcoin bsv"})
      assert tx.meta.title == "Bitcoin: A Peer-to-Peer Electronic Cash System"
      assert {:ok, []} = Txbox.all("test", %{search: "hubble photos"})
    end
  end


  describe "find/2" do
    setup do
      tx1 = fixture(%{rawtx: <<1,0,0,0,0,0,0,0,0,0>>, meta: %{title: "test1"}, tags: ["foo"]})
      tx2 = fixture(%{channel: "test", meta: %{title: "test2"}, tags: ["foo", "bar", "baz"]})
      %{tx1: tx1, tx2: tx2}
    end

    test "get a tx in default channel", %{tx1: %{txid: txid}} do
      assert {:ok, %Tx{channel: "txbox"} = tx} = Txbox.find(txid)
      assert tx.meta.title == "test1"
      assert is_nil(tx.rawtx)
    end

    test "get a tx with rawtx selected", %{tx1: %{txid: txid}} do
      assert {:ok, %Tx{channel: "txbox"} = tx} = Txbox.find(txid, rawtx: true)
      assert tx.meta.title == "test1"
      refute is_nil(tx.rawtx)
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


  describe "create/2" do
    test "add a tx to default channel" do
      txid = :crypto.strong_rand_bytes(32) |> Base.encode16
      assert {:ok, %Tx{} = tx} = Txbox.create(%{txid: txid, meta: %{title: "test-a"}})
      assert tx.meta.title == "test-a"
      assert tx.channel == "txbox"
    end

    test "add a tx to specific channel" do
      txid = :crypto.strong_rand_bytes(32) |> Base.encode16
      assert {:ok, %Tx{} = tx} = Txbox.create("test", %{txid: txid, meta: %{title: "test-b"}})
      assert tx.meta.title == "test-b"
      assert tx.channel == "test"
    end

    test "returns error with invalid attributes" do
      assert {:error, %{errors: errors}} = Txbox.create(%{})
      assert Keyword.keys(errors) |> Enum.member?(:txid)
    end
  end


  describe "update/2" do
    setup do
      tx1 = fixture(%{state: "pending", meta: %{title: "test1"}})
      tx2 = fixture(%{state: "queued", meta: %{title: "test2"}})
      %{tx1: tx1, tx2: tx2}
    end

    test "updates a pending tx with valid params", %{tx1: tx} do
      assert {:ok, %Tx{} = tx} = Txbox.update(tx, %{meta: %{title: "test-a"}})
      assert tx.meta.title == "test-a"
    end

    test "returns error with invalid params", %{tx1: tx} do
      assert {:error, %{errors: errors}} = Txbox.update(tx, %{txid: "zzzzz"})
      assert Keyword.keys(errors) |> Enum.member?(:txid)
    end

    test "returns error when updating non-pending tx", %{tx2: tx} do
      assert {:error, %{errors: errors}} = Txbox.update(tx, %{meta: %{title: "test-a"}})
      assert Keyword.get(errors, :base) |> elem(0) == "cannot mutate non-pending transaction"
    end
  end

end
