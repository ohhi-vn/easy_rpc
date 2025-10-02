defmodule EasyRpc.NodeSelector do
  @moduledoc """
  Node selection strategies for distributed RPC calls.

  This module provides different strategies for selecting target nodes
  when making remote procedure calls. It supports both static node lists
  and dynamic node discovery through MFA (Module, Function, Arguments).

  ## Selection Strategies

  ### `:random`
  Randomly selects a node from the available list on each call.
  Useful for simple load distribution without state.

  ### `:round_robin`
  Distributes calls across nodes in a circular pattern.
  **Note**: State is maintained per process, so each process has its own round-robin counter.

  ### `:hash`
  Uses consistent hashing based on function arguments to select a node.
  Same arguments will always route to the same node (unless the node list changes).
  Useful for cache locality and session affinity.

  ## Sticky Nodes

  When `sticky_node: true` is enabled, each process will "stick" to the first
  node it selects for all subsequent calls. This is useful for maintaining
  session state or connection pooling.

  **Note**: Sticky nodes are maintained per process using the process dictionary.

  ## Node Configuration

  Nodes can be configured in two ways:

  1. **Static list**: `nodes: [:node1@host, :node2@host]`
  2. **Dynamic MFA**: `nodes: {MyModule, :get_nodes, []}`

  The dynamic MFA approach is useful when:
  - Node topology changes at runtime
  - Using service discovery
  - Integrating with cluster management tools (e.g., ClusterHelper)

  ## Examples

      # Static node list with random selection
      selector = NodeSelector.new(
        [:node1@host, :node2@host],
        :my_selector_id,
        :random
      )

      # Dynamic nodes with round-robin
      selector = NodeSelector.new(
        {ClusterHelper, :get_nodes, [:backend]},
        :backend_selector,
        :round_robin,
        true  # sticky_node
      )

      # Select a node
      node = NodeSelector.select_node(selector, ["user_123"])
      #=> :node1@host

      # Load from application config
      selector = NodeSelector.load_config!(:my_app, :rpc_config)
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

  defstruct [
    :id,
    :nodes_or_mfa,
    strategy: :random,
    sticky_node: false
  ]

  ## Public API

  @doc """
  Creates a new NodeSelector with the given configuration.

  ## Parameters

  - `nodes_or_mfa` - Either a list of nodes or an MFA tuple for dynamic nodes
  - `id` - Unique identifier for this selector (used for process dictionary keys)
  - `strategy` - Selection strategy (`:random`, `:round_robin`, or `:hash`)
  - `sticky_node` - Whether to stick to the first selected node per process

  ## Returns

  A validated NodeSelector struct

  ## Examples

      NodeSelector.new([:node1@host, :node2@host], :my_id, :random)

      NodeSelector.new(
        {MyCluster, :nodes, []},
        :dynamic_id,
        :round_robin,
        true
      )

  ## Raises

  `EasyRpc.Error` if configuration is invalid
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
  Loads NodeSelector configuration from application config.

  ## Parameters

  - `app_name` - The application name (e.g., `:my_app`)
  - `config_name` - The configuration key (e.g., `:remote_nodes`)

  ## Expected Config Format

      config :my_app, :remote_nodes,
        nodes: [:node1@host, :node2@host],
        select_mode: :round_robin,
        sticky_node: false

  ## Returns

  A validated NodeSelector struct

  ## Examples

      selector = NodeSelector.load_config!(:my_app, :backend_nodes)

  ## Raises

  `EasyRpc.Error` if configuration is missing or invalid
  """
  @spec load_config!(app :: atom(), config_name :: atom()) :: t()
  def load_config!(app_name, config_name) do
    config = Application.get_env(app_name, config_name)

    unless config do
      Error.raise!(
        :config_error,
        "Configuration not found for #{inspect(app_name)}.#{inspect(config_name)}"
      )
    end

    %NodeSelector{
      nodes_or_mfa: Keyword.get(config, :nodes),
      strategy: Keyword.get(config, :select_mode, :random),
      sticky_node: Keyword.get(config, :sticky_node, false)
    }
    |> validate!()
  end

  @doc """
  Updates the selector ID.

  This is useful when you need to create multiple selectors with the same
  configuration but different process dictionary keys.

  ## Examples

      selector = NodeSelector.new(nodes, :id1, :random)
      selector2 = NodeSelector.update_id(selector, :id2)
  """
  @spec update_id(t(), selector_id()) :: t()
  def update_id(%NodeSelector{} = selector, id) do
    %{selector | id: id}
  end

  @doc """
  Selects a node based on the configured strategy.

  ## Parameters

  - `selector` - The NodeSelector configuration
  - `data` - Data to use for hash-based selection (typically function arguments)

  ## Returns

  The selected node

  ## Examples

      node = NodeSelector.select_node(selector, ["user_123"])
      #=> :node1@host

  ## Behavior

  - If sticky_node is enabled and a node was previously selected, returns that node
  - Otherwise selects a new node based on the strategy
  - For `:hash` strategy, the `data` parameter determines which node is selected
  - For `:round_robin`, maintains a counter per process
  - For `:random`, randomly selects from available nodes

  ## Raises

  `EasyRpc.Error` if no nodes are available or MFA returns invalid data
  """
  @spec select_node(t(), data :: term()) :: node()
  def select_node(%NodeSelector{} = selector, data) do
    case get_sticky_node(selector) do
      nil ->
        nodes = fetch_nodes(selector)
        node = select_by_strategy(nodes, selector.strategy, data, selector.id)
        maybe_store_sticky_node(selector, node)
        node

      cached_node ->
        cached_node
    end
  end

  @doc """
  Clears the sticky node for the current process.

  This is useful if you want to allow the process to select a new node.

  ## Examples

      NodeSelector.clear_sticky_node(selector)
  """
  @spec clear_sticky_node(t()) :: :ok
  def clear_sticky_node(%NodeSelector{sticky_node: true} = selector) do
    Process.delete({:easy_rpc, :sticky_node, selector.id})
    :ok
  end

  def clear_sticky_node(_selector), do: :ok

  @doc """
  Resets the round-robin counter for the current process.

  ## Examples

      NodeSelector.reset_round_robin(selector)
  """
  @spec reset_round_robin(t()) :: :ok
  def reset_round_robin(%NodeSelector{} = selector) do
    Process.delete({:easy_rpc, :round_robin, selector.id})
    :ok
  end

  ## Private Functions

  # Validates the NodeSelector configuration
  defp validate!(%NodeSelector{} = selector) do
    validate_nodes_config!(selector.nodes_or_mfa)
    validate_strategy!(selector.strategy)
    validate_sticky_node!(selector.sticky_node)
    selector
  end

  defp validate_nodes_config!(nodes) when is_list(nodes) do
    if Enum.empty?(nodes) do
      Error.raise!(
        :config_error,
        "Node list cannot be empty"
      )
    end

    unless Enum.all?(nodes, &is_atom/1) do
      Error.raise!(
        :config_error,
        "All nodes must be atoms, got: #{inspect(nodes)}"
      )
    end

    :ok
  end

  defp validate_nodes_config!({mod, fun, args})
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    :ok
  end

  defp validate_nodes_config!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid nodes configuration. Expected list of atoms or {module, function, args} tuple, got: #{inspect(invalid)}"
    )
  end

  defp validate_strategy!(strategy) when strategy in @strategies, do: :ok

  defp validate_strategy!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid strategy. Expected one of #{inspect(@strategies)}, got: #{inspect(invalid)}"
    )
  end

  defp validate_sticky_node!(value) when is_boolean(value), do: :ok

  defp validate_sticky_node!(invalid) do
    Error.raise!(
      :config_error,
      "sticky_node must be a boolean, got: #{inspect(invalid)}"
    )
  end

  # Fetches the node list, either from static config or by calling MFA
  defp fetch_nodes(%NodeSelector{nodes_or_mfa: nodes}) when is_list(nodes) do
    nodes
  end

  defp fetch_nodes(%NodeSelector{nodes_or_mfa: {module, function, args}}) do
    case apply(module, function, args) do
      nodes when is_list(nodes) and length(nodes) > 0 ->
        nodes

      [] ->
        Error.raise!(
          :node_error,
          "MFA #{inspect(module)}.#{inspect(function)} returned empty node list"
        )

      invalid ->
        Error.raise!(
          :config_error,
          "MFA #{inspect(module)}.#{inspect(function)} must return a list of nodes, got: #{inspect(invalid)}"
        )
    end
  end

  # Selects a node based on the strategy
  defp select_by_strategy(nodes, :random, _data, _id) do
    Enum.random(nodes)
  end

  defp select_by_strategy(nodes, :round_robin, _data, id) do
    current_index = get_round_robin_index(id, length(nodes))
    next_index = rem(current_index + 1, length(nodes))
    store_round_robin_index(id, next_index)
    Enum.at(nodes, current_index)
  end

  defp select_by_strategy(nodes, :hash, data, _id) do
    index = :erlang.phash2(data, length(nodes))
    Enum.at(nodes, index)
  end

  # Gets the sticky node from process dictionary
  defp get_sticky_node(%NodeSelector{sticky_node: true, id: id}) do
    Process.get({:easy_rpc, :sticky_node, id})
  end

  defp get_sticky_node(_selector), do: nil

  # Stores the sticky node in process dictionary
  defp maybe_store_sticky_node(%NodeSelector{sticky_node: true, id: id}, node) do
    Process.put({:easy_rpc, :sticky_node, id}, node)
  end

  defp maybe_store_sticky_node(_selector, _node), do: :ok

  # Gets the current round-robin index, initializing randomly if not set
  defp get_round_robin_index(id, node_count) do
    case Process.get({:easy_rpc, :round_robin, id}) do
      nil -> Enum.random(0..(node_count - 1))
      index when index >= node_count -> 0
      index -> index
    end
  end

  # Stores the round-robin index in process dictionary
  defp store_round_robin_index(id, index) do
    Process.put({:easy_rpc, :round_robin, id}, index)
  end
end
