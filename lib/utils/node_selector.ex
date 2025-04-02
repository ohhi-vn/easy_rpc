defmodule EasyRpc.NodeSelector do
  @moduledoc false

  alias __MODULE__

  alias EasyRpc.ConfigError

  @strategies [:random, :round_robin, :hash]

  defstruct [
    # for store sticky node
    :id,

    # nodes_or_mfa: [node()] | {module, function, args}
    :nodes_or_mfa,

    # strategy: :random | :round_robin | :hash
    strategy: :random,

    # sticky_node: true | false
    sticky_node: false
  ]

  @doc false
  def new(nodes_or_mfa, id, strategy \\ :random, sticky_node \\ false) do
    %NodeSelector{
      id: id,
      nodes_or_mfa: nodes_or_mfa,
      strategy: strategy,
      sticky_node: sticky_node
    }
    |> verify_config()
  end

  @doc false
  def load_config!(app_name, config_name) do
    config = Application.get_env(app_name, config_name)

    if config == nil do
      raise ConfigError, "not found configured for #{app_name}"
    end

    %NodeSelector{
      nodes_or_mfa: Keyword.get(config, :nodes),
      strategy: Keyword.get(config, :select_mode, :random),
      sticky_node: Keyword.get(config, :sticky_node, false)
    }
    |> verify_config()
  end

  @doc false
  def update_id(%NodeSelector{} = selector, id) do
    %NodeSelector{selector | id: id}
  end

  @doc false
  def select_node(%NodeSelector{} = selector, data) do
    case get_sticky_node(selector) do
      nil ->
        get_nodes(selector)
        |> select_new_node(selector, data)
        |> put_sticky_node(selector)

      last_node ->
        last_node
    end
  end

  ## Private functions ##

  defp verify_config(%NodeSelector{} = selector) do
    if not is_list(selector.nodes_or_mfa) and not is_tuple(selector.nodes_or_mfa) do
      raise ConfigError, "incorrected config for :nodes_or_mfa, required list or tuple, but get #{inspect(selector.nodes_or_mfa)}"
    end

    if not Enum.member?(@strategies, selector.strategy) do
      raise ConfigError, "incorrected config for strategy, required #{@strategies}, but get #{selector.strategy}"
    end

    if not is_boolean(selector.sticky_node) do
      raise ConfigError, "incorrected config for :sticky_node, required boolean, but get #{inspect(selector.sticky_node)}"
    end

    selector
  end

  defp select_new_node(nodes, %NodeSelector{} = selector, data) do
    case selector.strategy do
      :random -> Enum.random(nodes)
      :round_robin -> get_round_robin_order(nodes, selector.id)
      :hash -> Enum.at(nodes, get_hash_order(data, length(nodes)))
    end
  end

  defp get_nodes(%NodeSelector{nodes_or_mfa: nodes_or_mfa}) do
    case nodes_or_mfa do
      {module, function, args} ->
        case apply(module, function, args) do
          nodes when is_list(nodes) -> nodes
          unknown ->
            raise ConfigError, "incorrected config return by mfa for :nodes, required list, but get #{inspect(unknown)}"
        end
      nodes when is_list(nodes) -> nodes
    end
  end

  defp get_sticky_node(%NodeSelector{sticky_node: true} = selector) do
    Process.get({:easy_rpc, :sticky_node, selector.id}, nil)
  end
  defp get_sticky_node(_), do: nil

  defp put_sticky_node(node, %NodeSelector{sticky_node: true} = selector) do
    Process.put({:easy_rpc, :sticky_node, selector.id}, node)
    node
  end
  defp put_sticky_node(node, _selector), do: node

  defp get_hash_order(key, num_partitions) when num_partitions > 0 do
    :erlang.phash2(key, num_partitions)
  end

  defp get_round_robin_order(nodes, id) do
    current_index = Process.get({:easy_rpc, :round_robin, id}, Enum.random(0..length(nodes) - 1))
    current_index = if current_index >= length(nodes), do: 0, else: current_index
    Process.put({:easy_rpc, :round_robin, id}, current_index + 1)
    Enum.at(nodes, current_index)
  end
end
