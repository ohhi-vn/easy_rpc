defmodule EasyRpc do
  @moduledoc """
  A library for wrapping remote procedure calls (RPC) from remote nodes as local functions.

  EasyRpc simplifies distributed Elixir applications by allowing you to call functions
  on remote nodes as if they were local, with built-in support for:

  - **Automatic retry** - Configurable retry attempts on failure
  - **Timeout management** - Per-function or global timeout settings
  - **Error handling** - Optional error wrapping with detailed context
  - **Node selection strategies** - Random, round-robin, or hash-based selection
  - **Sticky nodes** - Pin RPC calls to specific nodes per process
  - **Dynamic node discovery** - Support for runtime node list changes

  ## Installation

  Add `easy_rpc` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:easy_rpc, "~> 0.6.0"}
    ]
  end
  ```

  ## Usage Approaches

  EasyRpc provides two approaches for wrapping remote functions:

  ### 1. DefRpc - Declarative Function Definitions

  Use `EasyRpc.DefRpc` when you want to explicitly declare each wrapped function
  in your module. This approach provides more control and is easier to debug.

  ```elixir
  # config/config.exs
  config :my_app, :remote_api,
    nodes: [:"api@node1", :"api@node2"],
    select_mode: :round_robin,
    sticky_node: true

  # lib/my_app/remote_api.ex
  defmodule MyApp.RemoteApi do
    use EasyRpc.DefRpc,
      otp_app: :my_app,
      config_name: :remote_api,
      module: RemoteNode.Api,
      timeout: 5_000

    # Define wrapped functions
    defrpc :get_user, args: 1
    defrpc :create_user, args: 2, retry: 3, timeout: 10_000
    defrpc :delete_user, args: 1, as: :remove_user, private: true
  end

  # Usage
  {:ok, user} = MyApp.RemoteApi.get_user(123)
  ```

  ### 2. RpcWrapper - Configuration-Based Generation

  Use `EasyRpc.RpcWrapper` when you want to define all functions in configuration.
  This approach is more declarative and keeps all RPC definitions in one place.

  ```elixir
  # config/config.exs
  config :my_app, :data_service,
    nodes: [:"data@node1", :"data@node2"],
    select_mode: :random,
    module: DataService.Interface,
    timeout: 5_000,
    error_handling: true,
    functions: [
      {:fetch_data, 1},
      {:store_data, 2, [retry: 3]},
      {:clear_cache, 0, [new_name: :reset_cache, timeout: 1_000]}
    ]

  # lib/my_app/data_helper.ex
  defmodule MyApp.DataHelper do
    use EasyRpc.RpcWrapper,
      otp_app: :my_app,
      config_name: :data_service

    def process_data(key) do
      case fetch_data(key) do
        {:ok, data} -> {:ok, transform(data)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Usage
  {:ok, data} = MyApp.DataHelper.fetch_data("user:123")
  ```

  ## Node Selection Strategies

  ### Random Selection
  Randomly distributes calls across available nodes.

  ```elixir
  config :my_app, :api,
    nodes: [:node1@host, :node2@host],
    select_mode: :random
  ```

  ### Round Robin
  Distributes calls in a circular pattern (per process).

  ```elixir
  config :my_app, :api,
    nodes: [:node1@host, :node2@host],
    select_mode: :round_robin
  ```

  ### Hash-Based Selection
  Routes calls based on argument hashing for consistency.

  ```elixir
  config :my_app, :api,
    nodes: [:node1@host, :node2@host],
    select_mode: :hash
  ```

  ### Sticky Nodes
  Pin to the first selected node for the lifetime of the process.

  ```elixir
  config :my_app, :api,
    nodes: [:node1@host, :node2@host],
    select_mode: :random,
    sticky_node: true
  ```

  ## Dynamic Node Discovery

  Use MFA (Module, Function, Arguments) tuple for runtime node resolution:

  ```elixir
  config :my_app, :api,
    nodes: {ClusterHelper, :get_nodes, [:backend]},
    select_mode: :random
  ```

  This is useful for:
  - Service discovery integration
  - Dynamic cluster topologies
  - Cloud-native deployments

  ## Error Handling

  ### Without Error Handling (Default)
  Functions raise exceptions on errors:

  ```elixir
  user = MyApi.get_user(123)  # Raises on error
  ```

  ### With Error Handling
  Functions return `{:ok, result}` or `{:error, reason}` tuples:

  ```elixir
  case MyApi.get_user(123) do
    {:ok, user} -> process_user(user)
    {:error, %EasyRpc.Error{} = error} ->
      Logger.error(EasyRpc.Error.format(error))
  end
  ```

  Enable globally:

  ```elixir
  config :my_app, :api,
    error_handling: true
  ```

  Or per function:

  ```elixir
  defrpc :get_user, args: 1, error_handling: true
  ```

  ## Retry Logic

  Automatic retry on failure with exponential backoff:

  ```elixir
  # Global retry
  config :my_app, :api,
    retry: 3

  # Per-function retry
  defrpc :critical_operation, args: 1, retry: 5
  ```

  **Note:** When `retry > 0`, error handling is automatically enabled.

  ## Timeout Configuration

  Set timeouts globally or per function:

  ```elixir
  # Global timeout
  config :my_app, :api,
    timeout: 5_000

  # Per-function timeout
  defrpc :long_operation, args: 1, timeout: 30_000
  defrpc :quick_check, args: 0, timeout: 1_000
  ```

  ## Integration with ClusterHelper

  EasyRpc works seamlessly with [ClusterHelper](https://hex.pm/packages/cluster_helper):

  ```elixir
  config :my_app, :api,
    nodes: {ClusterHelper, :get_nodes, [:api_cluster]},
    select_mode: :round_robin
  ```

  ## Best Practices

  1. **Use error handling for critical operations**
     ```elixir
     defrpc :transfer_funds, args: 3, error_handling: true, retry: 3
     ```

  2. **Set appropriate timeouts**
     ```elixir
     defrpc :health_check, args: 0, timeout: 1_000
     defrpc :generate_report, args: 1, timeout: 60_000
     ```

  3. **Choose the right selection strategy**
     - Use `:hash` for cache locality
     - Use `:round_robin` for even distribution
     - Use `:random` for simplicity
     - Use `sticky_node: true` for stateful connections

  4. **Handle network partitions gracefully**
     ```elixir
     config :my_app, :api,
       error_handling: true,
       retry: 3,
       timeout: 5_000
     ```

  5. **Monitor and log RPC calls**
     EasyRpc automatically logs RPC operations at various levels

  ## Troubleshooting

  ### Connection Errors
  ```elixir
  # Ensure nodes are connected
  Node.ping(:"remote@host")  #=> :pong

  # Check node list
  Node.list()
  ```

  ### Timeout Issues
  ```elixir
  # Increase timeout for slow operations
  defrpc :slow_operation, args: 1, timeout: 30_000
  ```

  ### Module Not Found
  Ensure the remote module is loaded on the target node:
  ```elixir
  :rpc.call(node, Code, :ensure_loaded?, [RemoteModule])
  ```

  ## Performance Considerations

  - RPC calls have network overhead (~1-5ms in typical LAN setups)
  - Use batching for multiple operations when possible
  - Consider caching frequently accessed data
  - Hash-based routing improves cache hit rates

  ## Related Modules

  - `EasyRpc.DefRpc` - Declarative function wrapper approach
  - `EasyRpc.RpcWrapper` - Configuration-based wrapper approach
  - `EasyRpc.NodeSelector` - Node selection strategies
  - `EasyRpc.WrapperConfig` - Configuration management
  - `EasyRpc.Error` - Error handling utilities

  ## Examples

  For complete working examples, see the [lib_examples repository](https://github.com/ohhi-vn/lib_examples/tree/main/easy_rpc).

  ## Support

  - Documentation: [https://hexdocs.pm/easy_rpc](https://hexdocs.pm/easy_rpc)
  - GitHub: [https://github.com/ohhi-vn/easy_rpc](https://github.com/ohhi-vn/easy_rpc)
  - Issues: [https://github.com/ohhi-vn/easy_rpc/issues](https://github.com/ohhi-vn/easy_rpc/issues)
  """

  @doc """
  Returns the current version of EasyRpc.

  ## Examples

      iex> EasyRpc.version()
      "0.6.0"
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:easy_rpc, :vsn) |> to_string()
  end
end
