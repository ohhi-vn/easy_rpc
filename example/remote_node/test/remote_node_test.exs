defmodule RemoteNodeTest do
  use ExUnit.Case
  doctest RemoteNode

  test "greets the world" do
    assert RemoteNode.hello() == :world
  end
end
