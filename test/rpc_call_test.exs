defmodule EasyRpc.RpcCallTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias EasyRpc.{RpcCall, WrapperConfig, NodeSelector, Error}

  # Local target module – callable via :erpc on Node.self()
  defmodule Target do
    def echo(x), do: x
    def add(a, b), do: a + b
    def identity(), do: :ok
    def raise_runtime(), do: raise("boom from rpc")
    def slow_op(), do: Process.sleep(10_000)
  end

  @nodes [Node.self()]

  defp make_config(opts \\ []) do
    selector = NodeSelector.new(@nodes, :rpc_call_test)

    WrapperConfig.new!(
      selector,
      EasyRpc.RpcCallTest.Target,
      Keyword.get(opts, :timeout, 5_000),
      Keyword.get(opts, :retry, 0),
      Keyword.get(opts, :error_handling, false)
    )
  end

  setup do
    Application.put_env(:easy_rpc_test, :rpc_dynamic_nodes,
      nodes: @nodes,
      select_mode: :random
    )

    :ok
  end

  ## ---- execute/3 without error handling ----

  describe "execute/3 — error_handling: false (default)" do
    test "returns raw result on success" do
      assert RpcCall.execute(make_config(), :echo, ["hello"]) == "hello"
    end

    test "works with zero-arg functions" do
      assert RpcCall.execute(make_config(), :identity, []) == :ok
    end

    test "works with multi-arg functions" do
      assert RpcCall.execute(make_config(), :add, [3, 4]) == 7
    end

    test "raises on remote exception" do
      assert_raise ErlangError, fn ->
        RpcCall.execute(make_config(), :raise_runtime, [])
      end
    end
  end

  ## ---- execute/3 with error_handling: true ----

  describe "execute/3 — error_handling: true" do
    test "returns {:ok, result} on success" do
      config = make_config(error_handling: true)
      assert {:ok, :ok} = RpcCall.execute(config, :identity, [])
    end

    test "wraps multi-arg results" do
      config = make_config(error_handling: true)
      assert {:ok, 7} = RpcCall.execute(config, :add, [3, 4])
    end

    test "returns {:error, %Error{}} on remote exception" do
      config = make_config(error_handling: true)
      assert {:error, %Error{}} = RpcCall.execute(config, :raise_runtime, [])
    end

    test "error has :rpc_error type for generic RuntimeError" do
      config = make_config(error_handling: true)
      {:error, err} = RpcCall.execute(config, :raise_runtime, [])
      assert err.type == :rpc_error
    end

    test "error details include node" do
      config = make_config(error_handling: true)
      {:error, err} = RpcCall.execute(config, :raise_runtime, [])
      assert Keyword.has_key?(err.details, :node)
    end

    test "logs failure at :error level" do
      config = make_config(error_handling: true)
      log = capture_log(fn -> RpcCall.execute(config, :raise_runtime, []) end)
      assert log =~ "failed permanently"
    end
  end

  ## ---- retry behaviour ----

  describe "execute/3 — retry logic" do
    test "retries specified number of times then returns {:error, _}" do
      config = make_config(retry: 2, error_handling: true)
      assert {:error, %Error{}} = RpcCall.execute(config, :raise_runtime, [])
    end

    test "logs retry warning for each failed attempt" do
      config = make_config(retry: 2, error_handling: true)
      log = capture_log(fn -> RpcCall.execute(config, :raise_runtime, []) end)
      assert log =~ "retries left"
    end

    test "logs permanent failure after all retries exhausted" do
      config = make_config(retry: 1, error_handling: true)
      log = capture_log(fn -> RpcCall.execute(config, :raise_runtime, []) end)
      assert log =~ "failed permanently after 2 attempt(s)"
    end

    test "retry with success on first call produces {:ok, result}" do
      config = make_config(retry: 3, error_handling: true)
      assert {:ok, "fine"} = RpcCall.execute(config, :echo, ["fine"])
    end
  end

  ## ---- execute_with_retry/3 ----

  describe "execute_with_retry/3" do
    test "returns {:ok, result} on success" do
      config = make_config(retry: 2)
      assert {:ok, 99} = RpcCall.execute_with_retry(config, :echo, [99])
    end

    test "returns {:error, _} when function always fails" do
      config = make_config(retry: 2)
      assert {:error, %Error{}} = RpcCall.execute_with_retry(config, :raise_runtime, [])
    end

    test "forces error_handling: true even if config has false" do
      config = make_config(retry: 0, error_handling: false)
      # Should not raise even with error_handling: false in config
      assert {:error, _} = RpcCall.execute_with_retry(config, :raise_runtime, [])
    end
  end

  ## ---- execute_dynamic/4 ----

  describe "execute_dynamic/4" do
    test "loads node selector at call time and executes successfully" do
      config = %WrapperConfig{
        node_selector: nil,
        module: EasyRpc.RpcCallTest.Target,
        timeout: 5_000,
        retry: 0,
        error_handling: true,
        functions: []
      }

      assert {:ok, :pong} =
               RpcCall.execute_dynamic(config, {:easy_rpc_test, :rpc_dynamic_nodes}, :echo, [
                 :pong
               ])
    end

    test "returns {:error, _} when remote call fails via dynamic config" do
      config = %WrapperConfig{
        node_selector: nil,
        module: EasyRpc.RpcCallTest.Target,
        timeout: 5_000,
        retry: 0,
        error_handling: true,
        functions: []
      }

      assert {:error, _} =
               RpcCall.execute_dynamic(
                 config,
                 {:easy_rpc_test, :rpc_dynamic_nodes},
                 :raise_runtime,
                 []
               )
    end
  end

  ## ---- backward-compat aliases ----

  describe "rpc_call/2 (backward compat)" do
    test "delegates to execute/3" do
      config = make_config(error_handling: true)
      assert {:ok, "hi"} = RpcCall.rpc_call(config, {:echo, ["hi"]})
    end
  end

  describe "rpc_call_dynamic/3 (backward compat)" do
    test "delegates to execute_dynamic/4" do
      config = %WrapperConfig{
        node_selector: nil,
        module: EasyRpc.RpcCallTest.Target,
        timeout: 5_000,
        retry: 0,
        error_handling: true,
        functions: []
      }

      assert {:ok, :ping} =
               RpcCall.rpc_call_dynamic(
                 config,
                 {:easy_rpc_test, :rpc_dynamic_nodes},
                 {:echo, [:ping]}
               )
    end
  end
end
