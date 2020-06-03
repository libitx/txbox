defmodule Bitbox.TransactionsTest do
  use Bitbox.Test.CaseTemplate
  alias Bitbox.Transactions
  alias Bitbox.Transactions.{Tx}

  @tx1 %{
    txid: "d0651c10fde1d4492270b8e8743d4b50111c05eab0d3512484013f2acbf0f41b"
  }

  @tx2 %{
    txid: "6dfccf46359e033053ab1975c1e008ddc98560f591e8ed1c8bd051050992c110",
    channel: "/testing"
  }

  def fixture(attrs \\ @tx1) do
    {:ok, tx} = Transactions.create(attrs)
    tx
  end


  describe "get/2" do
    setup do
      %{
        tx1: fixture(@tx1),
        tx2: fixture(@tx2)
      }
    end

    test "returns a tx", %{tx1: tx} do
      assert %Tx{} = tx = Transactions.get(tx.txid)
      assert tx.txid == @tx1.txid
      assert tx.channel == "/bitbox"
    end

    test "returns a tx when querying by channel", %{tx2: tx} do
      assert %Tx{} = tx =
        Transactions.by_channel("/testing")
        |> Transactions.get(tx.txid)
      assert tx.txid == @tx2.txid
      assert tx.channel == "/testing"
    end

    test "returns nil when not found" do
      assert Transactions.get("0000000000000000") == nil
    end
  end


  describe "all/1" do
    setup do
      %{
        tx1: fixture(@tx1),
        tx2: fixture(@tx2)
      }
    end

    test "returns all tx", ctx do
      txns = Transactions.all()
      assert length(txns) == 2
      assert Enum.member?(txns, ctx.tx1)
      assert Enum.member?(txns, ctx.tx2)
    end

    test "returns tx filtered by channel", %{tx2: tx} do
      txns =
        Transactions.by_channel("/testing")
        |> Transactions.all
      assert length(txns) == 1
      assert Enum.member?(txns, tx)
    end

    test "returns empty when none found" do
      assert [] =
        Transactions.by_channel("/foobar")
        |> Transactions.all
    end
  end


  describe "create/1" do
    test "returns Tx with valid attributes" do
      assert {:ok, %Tx{}} = Transactions.create(@tx1)
    end

    test "returns Changeset with invalid attributes" do
      assert {:error, %Ecto.Changeset{}} = Transactions.create(%{txid: "foobar"})
    end
  end


  describe "delete/1" do
    setup do
      %{tx: fixture(@tx1)}
    end

    test "deletes the given tx", %{tx: tx} do
      assert {:ok, %Tx{}} = Transactions.delete(tx)
      assert Transactions.get(tx.txid) == nil
    end
  end


  describe "update_status/2" do
    setup do
      %{tx: fixture(@tx1)}
    end


  end

end
