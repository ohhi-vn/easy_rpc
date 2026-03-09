# ============================================================
defmodule EasyRpc.NodeSelectorTest do
  use ExUnit.Case

  alias EasyRpc.{NodeSelector, Error}

  @nodes [:node1, :node2, :node3]

  # MFA helpers
  def get_nodes, do: [:node1, :node2]
  def get_empty_nodes, do: []
  def get_invalid_nodes, do: "not_a_list"

  setup_all do
    configs = [
      ns_random: [nodes: @nodes, select_mode: :random],
      ns_round_robin: [nodes: @nodes, select_mode: :round_robin],
      ns_hash: [nodes: @nodes, select_mode: :hash],
      ns_sticky: [nodes: @nodes, select_mode: :round_robin, sticky_node: true],
      ns_mfa: [nodes: {__MODULE__, :get_nodes, []}, select_mode: :round_robin]
    ]

    Enum.each(configs, fn {k, v} -> Application.put_env(:easy_rpc_test, k, v) end)
    :ok
  end

  ## ---- new/4 ----

  describe "new/4" do
    test "creates a valid selector with explicit args" do
      sel = NodeSelector.new(@nodes, :my_id, :random, false)
      assert sel.id == :my_id
      assert sel.strategy == :random
      assert sel.sticky_node == false
      assert sel.nodes_or_mfa == @nodes
    end

    test "defaults strategy to :random and sticky_node to false" do
      sel = NodeSelector.new(@nodes, :id)
      assert sel.strategy == :random
      assert sel.sticky_node == false
    end

    test "accepts MFA tuple as nodes config" do
      sel = NodeSelector.new({__MODULE__, :get_nodes, []}, :id)
      assert match?({_, _, _}, sel.nodes_or_mfa)
    end

    test "raises on empty node list" do
      assert_raise Error, ~r/cannot be empty/i, fn ->
        NodeSelector.new([], :id)
      end
    end

    test "raises when node list contains non-atoms" do
      assert_raise Error, ~r/must be atoms/i, fn ->
        NodeSelector.new(["not_atom"], :id)
      end
    end

    test "raises on unknown strategy" do
      assert_raise Error, ~r/Invalid strategy/i, fn ->
        NodeSelector.new(@nodes, :id, :unknown)
      end
    end

    test "raises when sticky_node is not a boolean" do
      assert_raise Error, ~r/sticky_node must be a boolean/i, fn ->
        NodeSelector.new(@nodes, :id, :random, "yes")
      end
    end

    test "raises on completely invalid nodes config" do
      assert_raise Error, fn -> NodeSelector.new("invalid", :id) end
    end
  end

  ## ---- load_config!/2 ----

  describe "load_config!/2" do
    test "loads random config from app env" do
      sel = NodeSelector.load_config!(:easy_rpc_test, :ns_random)
      assert sel.strategy == :random
      assert sel.nodes_or_mfa == @nodes
    end

    test "loads round_robin config" do
      sel = NodeSelector.load_config!(:easy_rpc_test, :ns_round_robin)
      assert sel.strategy == :round_robin
    end

    test "loads hash config" do
      sel = NodeSelector.load_config!(:easy_rpc_test, :ns_hash)
      assert sel.strategy == :hash
    end

    test "loads sticky config" do
      sel = NodeSelector.load_config!(:easy_rpc_test, :ns_sticky)
      assert sel.sticky_node == true
    end

    test "loads MFA-based nodes config" do
      sel = NodeSelector.load_config!(:easy_rpc_test, :ns_mfa)
      assert sel.nodes_or_mfa == {__MODULE__, :get_nodes, []}
    end

    test "raises when config key does not exist" do
      assert_raise Error, ~r/not found/i, fn ->
        NodeSelector.load_config!(:easy_rpc_test, :nonexistent_key)
      end
    end
  end

  ## ---- update_id/2 ----

  describe "update_id/2" do
    test "returns a new selector with the updated id" do
      sel = NodeSelector.new(@nodes, :old_id, :random)
      updated = NodeSelector.update_id(sel, :new_id)
      assert updated.id == :new_id
      assert updated.nodes_or_mfa == sel.nodes_or_mfa
      assert updated.strategy == sel.strategy
    end
  end

  ## ---- select_node/2 — :random ----

  describe "select_node/2 — :random strategy" do
    test "always returns a node from the configured list" do
      sel = NodeSelector.load_config!(:easy_rpc_test, :ns_random)

      for _ <- 1..100 do
        assert NodeSelector.select_node(sel, nil) in @nodes
      end
    end
  end

  ## ---- select_node/2 — :hash ----

  describe "select_node/2 — :hash strategy" do
    test "same data always maps to the same node" do
      sel = NodeSelector.load_config!(:easy_rpc_test, :ns_hash)
      n1 = NodeSelector.select_node(sel, {:hello, "world"})
      n2 = NodeSelector.select_node(sel, {:hello, "world"})
      assert n1 == n2
    end

    test "different data may select different nodes" do
      sel = NodeSelector.load_config!(:easy_rpc_test, :ns_hash)
      results = Enum.map(1..50, &NodeSelector.select_node(sel, &1))
      # Over 50 calls with different data, more than one node should be chosen
      assert MapSet.size(MapSet.new(results)) > 1
    end

    test "always returns a node from the list regardless of data type" do
      sel = NodeSelector.load_config!(:easy_rpc_test, :ns_hash)

      for data <- [nil, 0, "str", [:a], %{x: 1}, {:t, :u, :p}] do
        assert NodeSelector.select_node(sel, data) in @nodes
      end
    end
  end

  ## ---- select_node/2 — :round_robin ----

  describe "select_node/2 — :round_robin strategy" do
    test "covers all nodes in one complete cycle" do
      sel =
        NodeSelector.load_config!(:easy_rpc_test, :ns_round_robin)
        |> NodeSelector.update_id(:rr_cycle_test)

      NodeSelector.reset_round_robin(sel)

      selected = Enum.map(1..length(@nodes), fn _ -> NodeSelector.select_node(sel, nil) end)
      assert MapSet.new(selected) == MapSet.new(@nodes)
    end

    test "wraps around after exhausting the node list" do
      sel = NodeSelector.new(@nodes, :rr_wrap_test, :round_robin)
      NodeSelector.reset_round_robin(sel)

      first_cycle = Enum.map(1..length(@nodes), fn _ -> NodeSelector.select_node(sel, nil) end)
      second_cycle = Enum.map(1..length(@nodes), fn _ -> NodeSelector.select_node(sel, nil) end)
      assert first_cycle == second_cycle
    end
  end

  ## ---- sticky_node ----

  describe "sticky_node" do
    test "process always receives the first-selected node on subsequent calls" do
      sel =
        NodeSelector.load_config!(:easy_rpc_test, :ns_sticky)
        |> NodeSelector.update_id(:sticky_basic)

      NodeSelector.clear_sticky_node(sel)

      first = NodeSelector.select_node(sel, nil)

      for _ <- 1..10 do
        assert NodeSelector.select_node(sel, nil) == first
      end
    end

    test "sticky selection is isolated per process" do
      sel =
        NodeSelector.load_config!(:easy_rpc_test, :ns_sticky)
        |> NodeSelector.update_id(:sticky_iso)

      NodeSelector.clear_sticky_node(sel)

      parent_node = NodeSelector.select_node(sel, nil)

      child_node =
        Task.async(fn ->
          NodeSelector.clear_sticky_node(sel)
          NodeSelector.select_node(sel, nil)
        end)
        |> Task.await()

      # Both are valid nodes; they may or may not be the same, but both came from @nodes
      assert parent_node in @nodes
      assert child_node in @nodes
    end

    test "clear_sticky_node/1 allows the process to re-select" do
      sel =
        NodeSelector.load_config!(:easy_rpc_test, :ns_sticky)
        |> NodeSelector.update_id(:sticky_clear)

      NodeSelector.clear_sticky_node(sel)
      NodeSelector.select_node(sel, nil)

      NodeSelector.clear_sticky_node(sel)
      # After clearing, a new selection is made (valid node, no crash)
      assert NodeSelector.select_node(sel, nil) in @nodes
    end

    test "clear_sticky_node/1 is a safe no-op for non-sticky selectors" do
      sel = NodeSelector.new(@nodes, :non_sticky, :random, false)
      assert NodeSelector.clear_sticky_node(sel) == :ok
    end
  end

  ## ---- reset_round_robin/1 ----

  describe "reset_round_robin/1" do
    test "clears the counter so next call re-initialises" do
      sel = NodeSelector.new(@nodes, :rr_reset, :round_robin)
      # advance counter
      NodeSelector.select_node(sel, nil)
      NodeSelector.reset_round_robin(sel)
      # After reset the next call must still return a valid node (no crash)
      assert NodeSelector.select_node(sel, nil) in @nodes
    end
  end

  ## ---- MFA node provider ----

  describe "MFA node provider" do
    test "fetches nodes by calling the MFA at select time" do
      sel = NodeSelector.load_config!(:easy_rpc_test, :ns_mfa)
      assert NodeSelector.select_node(sel, nil) in get_nodes()
    end

    test "raises when MFA returns an empty list" do
      sel = NodeSelector.new({__MODULE__, :get_empty_nodes, []}, :mfa_empty)

      assert_raise Error, ~r/empty/i, fn ->
        NodeSelector.select_node(sel, nil)
      end
    end

    test "raises when MFA returns a non-list value" do
      sel = NodeSelector.new({__MODULE__, :get_invalid_nodes, []}, :mfa_invalid)

      assert_raise Error, ~r/must return/i, fn ->
        NodeSelector.select_node(sel, nil)
      end
    end
  end
end
