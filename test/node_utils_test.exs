defmodule EasyRpc.NodeUtilsTest do
  use ExUnit.Case
  doctest EasyRpc

  alias EasyRpc.NodeUtils

  @nodes [:node1, :node2, :node3, :node4, :node5]

  @nodes_2 [:node1, :node2]

  test "select random" do
    for _ <- 1..100 do
      assert NodeUtils.select_node(@nodes, :random, {nil, nil}) in @nodes
    end
  end

  test "select hash" do
    for _ <- 1..100 do
      assert NodeUtils.select_node(@nodes, :hash, {nil, nil}) in @nodes
    end
  end

  test "same hash if has same data" do
    node1 = NodeUtils.select_node(@nodes, :hash, {:hello, "world"})
    assert node1 in @nodes
    node2 = NodeUtils.select_node(@nodes, :hash,  {:hello, "world"})
    assert node2 in @nodes

    assert node1 == node2
  end

  test "select round-robin" do
    node = NodeUtils.select_node(@nodes, :round_robin, {__MODULE__, nil})
    assert node in @nodes

    node = NodeUtils.select_node(@nodes_2, :round_robin, {__MODULE__, nil})
    assert node == :node1
    node = NodeUtils.select_node(@nodes_2, :round_robin, {__MODULE__, nil})
    assert node == :node2
    node = NodeUtils.select_node(@nodes_2, :round_robin, {__MODULE__, nil})
    assert node == :node1
  end
end
