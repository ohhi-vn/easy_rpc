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

  # Provides bad node lists for runtime node-selection failure tests.
  # Must be a real named module so NodeSelector can apply/3 it.
  defmodule BadNodeProvider do
    def empty_nodes(), do: []
    def invalid_nodes(), do: "not_a_list"
  end

  @nodes [Node.self()]

  defp make_config(opts \\ []) do
    selector = NodeSelector.new(@nodes, :rpc_call_test)

    WrapperConfig.new!(
      selector,
      EasyRpc.RpcCallTest.Target,
      Keyword.get(opts, :timeout, 5_000),
      Keyword.get(opts, :retry, 0),
      Keyword.get(opts, :sleep_before_retry, 0),
      Keyword.get(opts, :error_handling, false)
    )
  end

  # Builds a config whose NodeSelector calls BadNodeProvider at runtime,
  # so node-selection errors happen inside execute/3 rather than at construction.
  defp make_bad_node_config(provider_fun, opts \\ []) do
    selector =
      NodeSelector.new(
        {EasyRpc.RpcCallTest.BadNodeProvider, provider_fun, []},
        :bad_node_test
      )

    WrapperConfig.new!(
      selector,
      EasyRpc.RpcCallTest.Target,
      Keyword.get(opts, :timeout, 5_000),
      Keyword.get(opts, :retry, 0),
      Keyword.get(opts, :sleep_before_retry, 0),
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

  ## ---- node selection failure (new tests for select_node_safe fix) ----

  describe "execute/3 — node selection failure, error_handling: true" do
    test "returns {:error, %Error{type: :node_error}} when MFA returns empty list" do
      config = make_bad_node_config(:empty_nodes, error_handling: true)
      assert {:error, %Error{type: :node_error}} = RpcCall.execute(config, :echo, ["x"])
    end

    test "returns {:error, %Error{}} when MFA returns invalid data" do
      config = make_bad_node_config(:invalid_nodes, error_handling: true)
      assert {:error, %Error{}} = RpcCall.execute(config, :echo, ["x"])
    end

    test "logs permanent failure when node selection fails" do
      config = make_bad_node_config(:empty_nodes, error_handling: true)
      log = capture_log(fn -> RpcCall.execute(config, :echo, ["x"]) end)
      assert log =~ "failed permanently"
    end

    test "node is reported as :unknown in the log when selection fails" do
      config = make_bad_node_config(:empty_nodes, error_handling: true)
      log = capture_log(fn -> RpcCall.execute(config, :echo, ["x"]) end)
      assert log =~ ":unknown"
    end

    test "does not raise — calling process stays alive" do
      config = make_bad_node_config(:empty_nodes, error_handling: true)

      result =
        capture_log(fn ->
          send(self(), RpcCall.execute(config, :echo, ["x"]))
        end)

      # Process is still running and the message arrived
      assert_received {:error, %Error{}}
      assert result =~ "[EasyRpc]"
    end
  end

  describe "execute/3 — node selection failure, error_handling: false (bare)" do
    test "raises EasyRpc.Error when MFA returns empty list" do
      config = make_bad_node_config(:empty_nodes)

      assert_raise EasyRpc.Error, fn ->
        RpcCall.execute(config, :echo, ["x"])
      end
    end

    test "logs failure before raising in bare mode" do
      config = make_bad_node_config(:empty_nodes)

      log =
        capture_log(fn ->
          assert_raise EasyRpc.Error, fn ->
            RpcCall.execute(config, :echo, ["x"])
          end
        end)

      assert log =~ "failed permanently"
    end

    test "raised error has :node_error type for empty node list" do
      config = make_bad_node_config(:empty_nodes)

      assert_raise EasyRpc.Error, ~r/node_error/, fn ->
        RpcCall.execute(config, :echo, ["x"])
      end
    end
  end

  describe "execute/3 — node selection failure, retry > 0" do
    test "retries all attempts then returns {:error, :node_error}" do
      config = make_bad_node_config(:empty_nodes, retry: 2, error_handling: true)
      assert {:error, %Error{type: :node_error}} = RpcCall.execute(config, :echo, ["x"])
    end

    test "logs retry warnings for each failed node selection attempt" do
      config = make_bad_node_config(:empty_nodes, retry: 2, error_handling: true)
      log = capture_log(fn -> RpcCall.execute(config, :echo, ["x"]) end)
      assert log =~ "retries left"
    end

    test "logs permanent failure after all node-selection retries exhausted" do
      config = make_bad_node_config(:empty_nodes, retry: 1, error_handling: true)
      log = capture_log(fn -> RpcCall.execute(config, :echo, ["x"]) end)
      assert log =~ "failed permanently after 2 attempt(s)"
    end
  end

  ## ---- sleep_before_retry ----

  describe "sleep_before_retry" do
    test "default is 0 — no measurable delay between retries" do
      config = make_config(retry: 2, error_handling: true)
      t0 = System.monotonic_time(:millisecond)
      RpcCall.execute(config, :raise_runtime, [])
      elapsed = System.monotonic_time(:millisecond) - t0
      # 3 attempts with 0 ms sleep — well under 100 ms even on slow CI
      assert elapsed < 100
    end

    test "sleeps between retries when sleep_before_retry > 0" do
      sleep_ms = 50
      config = make_config(retry: 2, sleep_before_retry: sleep_ms, error_handling: true)
      t0 = System.monotonic_time(:millisecond)
      RpcCall.execute(config, :raise_runtime, [])
      elapsed = System.monotonic_time(:millisecond) - t0
      # 2 sleeps of 50 ms each → at least 100 ms total
      assert elapsed >= sleep_ms * config.retry
    end

    test "sleeps before every retry, not before the first attempt" do
      # retry: 1 means 2 total attempts → exactly 1 sleep
      sleep_ms = 60
      config = make_config(retry: 1, sleep_before_retry: sleep_ms, error_handling: true)
      t0 = System.monotonic_time(:millisecond)
      RpcCall.execute(config, :raise_runtime, [])
      elapsed = System.monotonic_time(:millisecond) - t0
      assert elapsed >= sleep_ms
      # Should not have slept twice
      assert elapsed < sleep_ms * 3
    end

    test "sleep_before_retry does not affect successful calls" do
      config = make_config(retry: 2, sleep_before_retry: 50, error_handling: true)
      t0 = System.monotonic_time(:millisecond)
      assert {:ok, :ok} = RpcCall.execute(config, :identity, [])
      elapsed = System.monotonic_time(:millisecond) - t0
      # No retries triggered — no sleep occurred
      assert elapsed < 50
    end

    test "execute_with_retry/3 also respects sleep_before_retry" do
      sleep_ms = 50
      config = make_config(retry: 2, sleep_before_retry: sleep_ms)
      t0 = System.monotonic_time(:millisecond)
      RpcCall.execute_with_retry(config, :raise_runtime, [])
      elapsed = System.monotonic_time(:millisecond) - t0
      assert elapsed >= sleep_ms * config.retry
    end

    test "node selection failure also sleeps before retry" do
      sleep_ms = 50

      config =
        make_bad_node_config(:empty_nodes,
          retry: 2,
          sleep_before_retry: sleep_ms,
          error_handling: true
        )

      t0 = System.monotonic_time(:millisecond)
      RpcCall.execute(config, :echo, ["x"])
      elapsed = System.monotonic_time(:millisecond) - t0
      assert elapsed >= sleep_ms * config.retry
    end

    test "invalid sleep_before_retry raises config_error at construction" do
      selector = NodeSelector.new(@nodes, :rpc_call_test)

      assert_raise EasyRpc.Error, ~r/sleep_before_retry/, fn ->
        WrapperConfig.new!(selector, EasyRpc.RpcCallTest.Target, 5_000, 0, -1, false)
      end
    end
  end

  describe "execute_with_retry/3 — node selection failure" do
    test "returns {:error, :node_error} when node selection always fails" do
      config = make_bad_node_config(:empty_nodes, retry: 2)

      assert {:error, %Error{type: :node_error}} =
               RpcCall.execute_with_retry(config, :echo, ["x"])
    end

    test "does not raise even when node selection fails" do
      config = make_bad_node_config(:empty_nodes)

      assert {:error, %Error{}} = RpcCall.execute_with_retry(config, :echo, ["x"])
    end
  end
end

