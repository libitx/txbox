defmodule BitboxTest do
  use Bitbox.Test.CaseTemplate
  doctest Bitbox

  test "greets the world" do
    assert Bitbox.hello() == :world
  end
end
