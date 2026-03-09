defmodule EasyRpcTest do
  use ExUnit.Case

  test "version/0 returns a binary string" do
    assert is_binary(EasyRpc.version())
  end
end
