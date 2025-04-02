defmodule EasyRpc.NodeSelectorTest do
  use ExUnit.Case

  doctest EasyRpc.NodeSelector

  alias EasyRpc.NodeSelector

  @nodes [:node1, :node2, :node3]

  @mfa {__MODULE__, :get_node, []}

  setup_all do
    add_env_config()
    {:ok, state: :ok}
  end

  defp add_env_config do
    config1 =
      [
        nodes: @nodes,
        select_mode: :random,
      ]
    config2 =
      [
        nodes: @nodes,
        select_mode: :round_robin,
      ]
    config3 =
      [
        nodes: @mfa,
        select_mode: :round_robin,
      ]
    config4 =
      [
        nodes: @nodes,
        select_mode: :round_robin,
        sticky_node: true,
      ]
    config5 =
      [
        nodes: @nodes,
        select_mode: :hash,
      ]

    Application.put_env(:easy_rpc_test, :config1, config1)
    Application.put_env(:easy_rpc_test, :config2, config2)
    Application.put_env(:easy_rpc_test, :config3, config3)
    Application.put_env(:easy_rpc_test, :config4, config4)
    Application.put_env(:easy_rpc_test, :config5, config5)
  end

  test "select random" do
    node_selector = NodeSelector.load_config!(:easy_rpc_test, :config1)
    for _ <- 1..100 do
      assert NodeSelector.select_node(node_selector, {__MODULE__, nil}) in @nodes
    end
  end

  test "select hash" do
    node_selector = NodeSelector.load_config!(:easy_rpc_test, :config5)
    for _ <- 1..100 do
      assert NodeSelector.select_node(node_selector, {nil, nil}) in @nodes
    end
  end

  test "hash, same node if has same data" do
    node_selector = NodeSelector.load_config!(:easy_rpc_test, :config5)

    node1 = NodeSelector.select_node(node_selector, {:hello, "world"})
    assert node1 in @nodes
    node2 = NodeSelector.select_node(node_selector, {:hello, "world"})
    assert node2 in @nodes

    assert node1 == node2
  end

  test "select round-robin" do
    node_selector = NodeSelector.load_config!(:easy_rpc_test, :config2)

    selected_node =
      Enum.map(@nodes, fn _node ->
        NodeSelector.select_node(node_selector, {__MODULE__, nil})
      end)

    orig = MapSet.new(@nodes)
    selected = MapSet.new(selected_node)
    assert selected == orig
  end

  test "select round-robin sticky-node" do
    node_selector = NodeSelector.load_config!(:easy_rpc_test, :config4)

    last_node = NodeSelector.select_node(node_selector, {__MODULE__, nil})

    node = NodeSelector.select_node(node_selector, {__MODULE__, nil})
    assert node == last_node
    node = NodeSelector.select_node(node_selector, {__MODULE__, nil})
    assert node == last_node
    node = NodeSelector.select_node(node_selector, {__MODULE__, nil})
    assert node == last_node
  end

  test "select node with module" do
    node_selector = NodeSelector.load_config!(:easy_rpc_test, :config3)

    assert NodeSelector.select_node(node_selector, {__MODULE__, nil}) in get_node()
  end

  def get_node do
    [:node1, :node2]
  end
end
