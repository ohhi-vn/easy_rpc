defmodule EasyRpc.SparkDslTest do
  use ExUnit.Case, async: false
  doctest EasyRpc

  describe "Spark DSL compilation" do
    test "compiles module with DSL" do
      quoted =
        quote do
          defmodule TestRemoteApi do
            use EasyRpc

            config do
              nodes [:node1, :node2]
              select_mode :round_robin
              module RemoteNode.Api
              timeout 5_000
              retry 0
              error_handling false
            end

            rpc_functions do
              rpc_function :get_user, 1
              rpc_function :create_user, 2
              rpc_function :delete_user, 1, new_name: :remove_user, private: true
            end
          end
        end

      # Compile the module
      Code.compile_quoted(quoted)

      # Verify the module was defined
      assert Code.ensure_loaded?(TestRemoteApi)

      # Verify functions were generated
      assert function_exported?(TestRemoteApi, :get_user, 1)
      assert function_exported?(TestRemoteApi, :create_user, 2)
      # remove_user is private (new_name with private: true)
      refute function_exported?(TestRemoteApi, :remove_user, 1)
      refute function_exported?(TestRemoteApi, :delete_user, 1)
    end

    test "compiles with argument names syntax (better IDE support)" do
      quoted =
        quote do
          defmodule TestArgNamesApi do
            use EasyRpc

            config do
              nodes [:node1]
              module RemoteNode.Api
              timeout 5_000
            end

            rpc_functions do
              # Using argument names instead of integer arity
              rpc_function :get_user, [:user_id]
              rpc_function :create_user, [:user_id, :name]
              rpc_function :update_user, [:user_id, :attrs, :opts]
            end
          end
        end

      Code.compile_quoted(quoted)

      assert Code.ensure_loaded?(TestArgNamesApi)
      assert function_exported?(TestArgNamesApi, :get_user, 1)
      assert function_exported?(TestArgNamesApi, :create_user, 2)
      assert function_exported?(TestArgNamesApi, :update_user, 3)
    end

    test "compiles with nodes_provider (dynamic node discovery)" do
      # Define a node provider module
      Code.compile_quoted(
        quote do
          defmodule TestNodeProvider do
            def get_nodes(_), do: [node()]
          end
        end
      )

      quoted =
        quote do
          defmodule TestDynamicNodesApi do
            use EasyRpc

            config do
              nodes_provider {TestNodeProvider, :get_nodes, [:test]}
              module RemoteNode.Api
              timeout 5_000
            end

            rpc_functions do
              rpc_function :get_data, [:key]
            end
          end
        end

      Code.compile_quoted(quoted)

      assert Code.ensure_loaded?(TestDynamicNodesApi)
      assert function_exported?(TestDynamicNodesApi, :get_data, 1)
    end

    test "nodes_provider works with different argument patterns" do
      # Define a node provider module with different arg patterns
      Code.compile_quoted(
        quote do
          defmodule TestMultiProvider do
            def get_nodes_no_args(), do: [:node1]
            def get_nodes_with_args(region, env), do: [:node1]
          end
        end
      )

      # Test with no args
      quoted1 =
        quote do
          defmodule TestDynNodes1 do
            use EasyRpc

            config do
              nodes_provider {TestMultiProvider, :get_nodes_no_args, []}
              module RemoteNode.Api
            end

            rpc_functions do
              rpc_function :get_data, [:key]
            end
          end
        end

      Code.compile_quoted(quoted1)
      assert Code.ensure_loaded?(TestDynNodes1)
      assert function_exported?(TestDynNodes1, :get_data, 1)

      # Test with args
      quoted2 =
        quote do
          defmodule TestDynNodes2 do
            use EasyRpc

            config do
              nodes_provider {TestMultiProvider, :get_nodes_with_args, [:us, :prod]}
              module RemoteNode.Api
            end

            rpc_functions do
              rpc_function :get_data, [:key]
            end
          end
        end

      Code.compile_quoted(quoted2)
      assert Code.ensure_loaded?(TestDynNodes2)
      assert function_exported?(TestDynNodes2, :get_data, 1)
    end

    test "argument names syntax preserves function arity" do
      quoted =
        quote do
          defmodule TestArgNamesPreserved do
            use EasyRpc

            config do
              nodes [:node1]
              module RemoteNode.Api
            end

            rpc_functions do
              rpc_function :get_user, [:user_id]
              rpc_function :create_user, [:user_id, :name, :email]
            end
          end
        end

      Code.compile_quoted(quoted)
      assert Code.ensure_loaded?(TestArgNamesPreserved)

      # Verify functions exist with correct arity
      assert function_exported?(TestArgNamesPreserved, :get_user, 1)
      assert function_exported?(TestArgNamesPreserved, :create_user, 3)
    end
  end

    test "Info module returns correct information" do
      quoted =
        quote do
          defmodule TestApiInfo do
            use EasyRpc

            config do
              nodes [:node1]
              module RemoteNode.Api
            end

            rpc_functions do
              rpc_function :test_func, 1
            end
          end
        end

      Code.compile_quoted(quoted)

      # Test Info functions
      {:ok, nodes} = EasyRpc.Info.config_nodes(TestApiInfo)
      assert nodes == [:node1]

      {:ok, module} = EasyRpc.Info.config_module(TestApiInfo)
      assert module == RemoteNode.Api

      functions = EasyRpc.Info.rpc_functions(TestApiInfo)
      assert length(functions) == 1
      [fun] = functions
      assert fun.name == :test_func
      assert fun.arity == 1
    end


  describe "enable_logging config" do
    test "logging is disabled when enable_logging: false" do
      quoted =
        quote do
          defmodule TestLoggingDisabled do
            use EasyRpc

            config do
              nodes [:node1]
              module RemoteNode.Api
              enable_logging false
            end

            rpc_functions do
              rpc_function :test_func, 1
            end
          end
        end

      Code.compile_quoted(quoted)
      # Just verify it compiles - actual logging behavior tested in rpc_call_test.exs
      assert Code.ensure_loaded?(TestLoggingDisabled)
    end

    test "logging is enabled by default" do
      quoted =
        quote do
          defmodule TestLoggingDefault do
            use EasyRpc

            config do
              nodes [:node1]
              module RemoteNode.Api
            end

            rpc_functions do
              rpc_function :test_func, 1
            end
          end
        end

      Code.compile_quoted(quoted)
      assert Code.ensure_loaded?(TestLoggingDefault)
    end
  end
end
