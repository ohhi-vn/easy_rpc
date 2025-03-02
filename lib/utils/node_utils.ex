defmodule EasyRpc.NodeUtils do
  @moduledoc """
  NodeUtils is a helper module to help get target node in Elixir cluster.
  Support strategies: random, round-robin, hash.
  For case round-robin, the module will using process dictionary to store the current index.
  """

  @doc """
  Helper function to calculate target node by random, round-robin, or hash.
  """
  @spec select_node([node()], :random | :round_robin | :hash, {atom(), any()}) :: node()
  def select_node(nodes, strategy, {module, data}) do
    case strategy do
      :random -> Enum.random(nodes)
      :round_robin -> get_round_robin_order(nodes, module)
      :hash -> Enum.at(nodes, get_hash_order(data, length(nodes)))
    end
  end

  ## Private functions ##

  defp get_hash_order(key, num_partitions) when num_partitions > 0 do
    :erlang.phash2(key, num_partitions)
  end

  defp get_round_robin_order(nodes, module) do
    current_index = (Process.get({:easy_rpc, :round_robin, module}) || 0) + 1
    current_index = if current_index >= length(nodes), do: 0, else: current_index
    Process.put({:easy_rpc, :round_robin, module}, current_index)
    Enum.at(nodes, current_index)
  end
end
