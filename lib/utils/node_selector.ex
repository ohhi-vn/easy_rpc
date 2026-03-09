defmodule EasyRpc.NodeSelector do
  @moduledoc """
  Node selection strategies for distributed RPC calls.

  Supports both static node lists and dynamic node discovery through
  MFA (Module, Function, Arguments).

  ## Selection Strategies

  - `:random`      - Randomly picks a node on each call.
  - `:round_robin` - Circular distribution, tracked per-process.
  - `:hash`        - Consistent hashing on function arguments.
                     Same args always route to the same node.

  ## Sticky Nodes

  When `sticky_node: true`, a process sticks to the first node it selects
  for all subsequent calls (stored in the process dictionary).

  ## Node Configuration

  - **Static list**: `nodes: [:node1@host, :node2@host]`
  - **Dynamic MFA**: `nodes: {MyModule, :get_nodes, []}`

  ## Examples

      selector = NodeSelector.new([:n1@host, :n2@host], :my_id, :random)

      selector = NodeSelector.new(
        {ClusterHelper, :get_nodes, [:backend]},
        :backend_selector,
        :round_robin,
        true
      )

      node = NodeSelector.select_node(selector, ["user_123"])
      #=> :n1@host
  """

  alias __MODULE__
  alias EasyRpc.Error

  @type node_list :: [node()]
  @type nodes_mfa :: {module :: atom(), function :: atom(), args :: list()}
  @type nodes_config :: node_list() | nodes_mfa()
  @type strategy :: :random | :round_robin | :hash
  @type selector_id :: term()

  @type t :: %__MODULE__{
          id: selector_id(),
          nodes_or_mfa: nodes_config(),
          strategy: strategy(),
          sticky_node: boolean()
        }

  @strategies [:random, :round_robin, :hash]

  defstruct [:id, :nodes_or_mfa, strategy: :random, sticky_node: false]

  ## Public API

  @doc """
  Creates and validates a new `NodeSelector`.
  Raises `EasyRpc.Error` if any option is invalid.
  """
  @spec new(nodes_config(), selector_id(), strategy(), boolean()) :: t()
  def new(nodes_or_mfa, id, strategy \\ :random, sticky_node \\ false) do
    %NodeSelector{
      id: id,
      nodes_or_mfa: nodes_or_mfa,
      strategy: strategy,
      sticky_node: sticky_node
    }
    |> validate!()
  end

  @doc """
  Loads a `NodeSelector` from application config.

  Expected format:

      config :my_app, :remote_nodes,
        nodes: [:node1@host, :node2@host],
        select_mode: :round_robin,
        sticky_node: false

  Raises `EasyRpc.Error` if config is missing or invalid.
  """
  @spec load_config!(app :: atom(), config_name :: atom()) :: t()
  def load_config!(app_name, config_name) do
    config = Application.get_env(app_name, config_name)

    unless config do
      Error.raise!(
        :config_error,
        "NodeSelector config not found: #{inspect(app_name)}.#{inspect(config_name)}"
      )
    end

    %NodeSelector{
      nodes_or_mfa: Keyword.get(config, :nodes),
      strategy: Keyword.get(config, :select_mode, :random),
      sticky_node: Keyword.get(config, :sticky_node, false)
    }
    |> validate!()
  end

  @doc "Updates the selector's `:id` field."
  @spec update_id(t(), selector_id()) :: t()
  def update_id(%NodeSelector{} = selector, id), do: %{selector | id: id}

  @doc """
  Selects a node using the configured strategy.

  - Respects sticky-node state stored in the process dictionary.
  - `data` is only used by the `:hash` strategy.

  Raises `EasyRpc.Error` when no nodes are available.
  """
  @spec select_node(t(), data :: term()) :: node()
  def select_node(%NodeSelector{} = selector, data) do
    case get_sticky_node(selector) do
      nil ->
        node =
          selector |> fetch_nodes() |> select_by_strategy(selector.strategy, data, selector.id)

        maybe_store_sticky_node(selector, node)
        node

      cached_node ->
        cached_node
    end
  end

  @doc "Clears the sticky node for the current process."
  @spec clear_sticky_node(t()) :: :ok
  def clear_sticky_node(%NodeSelector{sticky_node: true, id: id}) do
    Process.delete({:easy_rpc, :sticky_node, id})
    :ok
  end

  def clear_sticky_node(_selector), do: :ok

  @doc "Resets the round-robin counter for the current process."
  @spec reset_round_robin(t()) :: :ok
  def reset_round_robin(%NodeSelector{id: id}) do
    Process.delete({:easy_rpc, :round_robin, id})
    :ok
  end

  ## Private — Validation

  defp validate!(%NodeSelector{} = selector) do
    validate_nodes_config!(selector.nodes_or_mfa)
    validate_strategy!(selector.strategy)
    validate_sticky_node!(selector.sticky_node)
    selector
  end

  defp validate_nodes_config!(nodes) when is_list(nodes) and length(nodes) > 0 do
    unless Enum.all?(nodes, &is_atom/1) do
      Error.raise!(:config_error, "All nodes must be atoms, got: #{inspect(nodes)}")
    end

    :ok
  end

  defp validate_nodes_config!([]) do
    Error.raise!(:config_error, "Node list cannot be empty")
  end

  defp validate_nodes_config!({mod, fun, args})
       when is_atom(mod) and is_atom(fun) and is_list(args), do: :ok

  defp validate_nodes_config!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid nodes config — expected list of atoms or {module, fun, args}, got: #{inspect(invalid)}"
    )
  end

  defp validate_strategy!(s) when s in @strategies, do: :ok

  defp validate_strategy!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid strategy — expected one of #{inspect(@strategies)}, got: #{inspect(invalid)}"
    )
  end

  defp validate_sticky_node!(v) when is_boolean(v), do: :ok

  defp validate_sticky_node!(invalid) do
    Error.raise!(:config_error, "sticky_node must be a boolean, got: #{inspect(invalid)}")
  end

  ## Private — Node Fetching

  defp fetch_nodes(%NodeSelector{nodes_or_mfa: nodes}) when is_list(nodes), do: nodes

  defp fetch_nodes(%NodeSelector{nodes_or_mfa: {mod, fun, args}}) do
    case apply(mod, fun, args) do
      [_ | _] = nodes ->
        nodes

      [] ->
        Error.raise!(
          :node_error,
          "Dynamic node provider #{inspect(mod)}.#{fun}/#{length(args)} returned an empty list"
        )

      invalid ->
        Error.raise!(
          :config_error,
          "Dynamic node provider #{inspect(mod)}.#{fun}/#{length(args)} must return a non-empty " <>
            "list of atoms, got: #{inspect(invalid)}"
        )
    end
  end

  ## Private — Strategy Selection

  defp select_by_strategy(nodes, :random, _data, _id),
    do: Enum.random(nodes)

  defp select_by_strategy(nodes, :round_robin, _data, id) do
    count = length(nodes)
    idx = get_round_robin_index(id, count)
    store_round_robin_index(id, rem(idx + 1, count))
    Enum.at(nodes, idx)
  end

  defp select_by_strategy(nodes, :hash, data, _id) do
    Enum.at(nodes, :erlang.phash2(data, length(nodes)))
  end

  ## Private — Process Dictionary Helpers

  defp get_sticky_node(%NodeSelector{sticky_node: true, id: id}),
    do: Process.get({:easy_rpc, :sticky_node, id})

  defp get_sticky_node(_), do: nil

  defp maybe_store_sticky_node(%NodeSelector{sticky_node: true, id: id}, node),
    do: Process.put({:easy_rpc, :sticky_node, id}, node)

  defp maybe_store_sticky_node(_selector, _node), do: :ok

  defp get_round_robin_index(id, count) do
    case Process.get({:easy_rpc, :round_robin, id}) do
      nil -> Enum.random(0..(count - 1))
      idx when idx >= count -> 0
      idx -> idx
    end
  end

  defp store_round_robin_index(id, idx),
    do: Process.put({:easy_rpc, :round_robin, id}, idx)
end
