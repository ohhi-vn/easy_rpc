defmodule EasyRpc do
  @moduledoc """
  Main DSL module for EasyRpc.

  Use this module to define RPC wrappers with the Spark DSL:

      defmodule MyApp.RemoteApi do
        use EasyRpc

        config do
          # Option 1: Static node list
          nodes [:"api@node1", :"api@node2"]
          select_mode :round_robin
          module RemoteNode.Api
          timeout 5_000
        end

        rpc_functions do
          # Option 1: Using integer arity
          rpc_function :get_user, 1
          rpc_function :create_user, 2

          # Option 2: Using argument names (better IDE support)
          rpc_function :get_user, [:user_id]
          rpc_function :create_user, [:user_id, :name]
        end
      end

  ## Dynamic Node Discovery

  You can also use dynamic node discovery via MFA (Module, Function, Args):

      config do
        # Option 2: Dynamic node discovery
        nodes_provider {MyApp.Cluster, :get_backend_nodes, [:region]}
        module RemoteNode.Api
        timeout 5_000
      end

  The function must return a list of node names.
  """

  use Spark.Dsl,
    default_extensions: [
      extensions: [EasyRpc.Dsl]
    ]

  @doc """
  Returns the current version of EasyRpc.

  ## Examples

      iex> EasyRpc.version()
      "0.9.0"
  """
  @spec version() :: String.t()
  def version do
    Application.spec(:easy_rpc, :vsn) |> to_string()
  end
end
