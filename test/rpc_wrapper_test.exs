defmodule EasyRpc.RpcWrapperTest do
  use ExUnit.Case

  alias EasyRpc.RpcWrapper

  # Remote target: runs locally via Node.self()
  defmodule Target do
    def utc_now(), do: DateTime.utc_now()
    def to_iso(dt), do: DateTime.to_iso8601(dt)
    def diff(a, b, unit), do: DateTime.diff(a, b, unit)
    def echo(x), do: x
    def raise_an_error(), do: raise("wrapper error")
    def retry_me(_n), do: raise("always fails")
  end

  # Put env at module load time so it's available when the wrapper
  # modules below are compiled (setup_all runs too late for `use` macros).
  Application.put_env(:easy_rpc_test, :rw_basic,
    nodes: [Node.self()],
    module: EasyRpc.RpcWrapperTest.Target,
    functions: [
      {:utc_now, 0},
      {:to_iso, 1, [new_name: :to_iso_str]},
      {:diff, 3, [private: true]},
      {:echo, 1}
    ]
  )

  Application.put_env(:easy_rpc_test, :rw_errors,
    nodes: [Node.self()],
    module: EasyRpc.RpcWrapperTest.Target,
    error_handling: false,
    functions: [
      {:raise_an_error, 0},
      {:raise_an_error, 0, [new_name: :safe_error, error_handling: true]},
      {:retry_me, 1, [new_name: :retry_error, retry: 2]}
    ]
  )

  # Wrapper modules defined after env is set.

  defmodule Basic do
    use RpcWrapper, otp_app: :easy_rpc_test, config_name: :rw_basic

    # Exposes the private diff/3 for testing
    def public_diff(a, b, u), do: diff(a, b, u)
  end

  defmodule ErrorWrapper do
    use RpcWrapper, otp_app: :easy_rpc_test, config_name: :rw_errors
  end

  ## ---- Tests ----

  # No setup_all needed — env is set at module load time above.

  describe "public function generation" do
    test "zero-arg function returns expected value" do
      assert %DateTime{} = Basic.utc_now()
    end

    test "single-arg function works" do
      now = DateTime.utc_now()
      assert Basic.echo(now) == now
    end

    test "renamed function works via :new_name" do
      now = DateTime.utc_now()
      assert Basic.to_iso_str(now) == DateTime.to_iso8601(now)
    end
  end

  describe "private function generation" do
    test "private function is NOT exported" do
      assert_raise UndefinedFunctionError, fn ->
        apply(Basic, :diff, [DateTime.utc_now(), DateTime.utc_now(), :second])
      end
    end

    test "private function IS callable from within the module" do
      now = DateTime.utc_now()
      assert Basic.public_diff(now, now, :second) == 0
    end
  end

  describe "error handling" do
    test "error_handling: true returns {:error, _} on exception" do
      assert {:error, _} = ErrorWrapper.safe_error()
    end

    test "no error_handling raises ErlangError on exception" do
      assert_raise ErlangError, fn -> ErrorWrapper.raise_an_error() end
    end

    test "retry returns {:error, _} after all attempts exhausted" do
      assert {:error, _} = ErrorWrapper.retry_error(1)
    end
  end

  describe "compile-time validation" do
    test "missing :otp_app raises KeyError at module definition" do
      assert_raise KeyError, fn ->
        defmodule BadRpcWrapper1 do
          use RpcWrapper, config_name: :some_config
        end
      end
    end

    test "missing :config_name raises KeyError at module definition" do
      assert_raise KeyError, fn ->
        defmodule BadRpcWrapper2 do
          use RpcWrapper, otp_app: :easy_rpc_test
        end
      end
    end
  end
end
