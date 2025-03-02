defmodule EasyRpcTest do
  use ExUnit.Case
  doctest EasyRpc

  test "greets the world" do
    assert EasyRpc.hello() == :world
  end
end
