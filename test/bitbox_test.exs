defmodule BitboxTest do
  use ExUnit.Case
  doctest Bitbox

  test "greets the world" do
    assert Bitbox.hello() == :world
  end
end
