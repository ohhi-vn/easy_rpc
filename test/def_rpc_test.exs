defmodule EasyRpc.DefRpcTest do
  use ExUnit.Case

  alias EasyRpc.DefRpc

  # Remote target: runs locally via Node.self()
  defmodule Remote do
    def say_hello(), do: :hello
    def echo(x), do: x
    def greeting(name), do: "Hello, #{name}"
    def to_list(a, b), do: [a, b]
    def named_pair(first, second), do: {first, second}
    def raise_runtime(), do: raise("runtime error")
    def raise_with_arg(n), do: raise("error #{n}")
  end

  # MFA helper — must be defined before Application.put_env referencing it,
  # and before the wrapper modules that trigger load_config! at compile time.
  def get_node, do: [Node.self()]

  # Put env at module load time so the `use DefRpc` macros below can call
  # load_config! successfully during compilation.
  Application.put_env(:easy_rpc_test, :dr_basic,
    nodes: [Node.self()],
    select_mode: :random
  )

  Application.put_env(:easy_rpc_test, :dr_mfa,
    nodes: {EasyRpc.DefRpcTest, :get_node, []},
    select_mode: :round_robin
  )

  defmodule BasicWrapper do
    use DefRpc,
      otp_app: :easy_rpc_test,
      config_name: :dr_basic,
      module: EasyRpc.DefRpcTest.Remote,
      timeout: :infinity

    defrpc(:say_hello)
    defrpc(:echo, args: 1)
    defrpc(:greeting, args: 1, as: :greet)
    defrpc(:to_list, args: 2, as: :make_list)
    defrpc(:to_list, args: 2, as: :private_list, private: true)
    defrpc(:named_pair, args: [:first, :second], as: :pair)
    defrpc(:raise_runtime, as: :safe_raise, error_handling: true)
    defrpc(:raise_runtime, as: :retry_raise, retry: 2)
    defrpc(:raise_runtime, as: :bare_raise)
    defrpc(:raise_with_arg, args: 1, as: :raise_arg)

    def call_private(a, b), do: private_list(a, b)
  end

  defmodule MfaWrapper do
    use DefRpc,
      otp_app: :easy_rpc_test,
      config_name: :dr_mfa,
      module: EasyRpc.DefRpcTest.Remote,
      timeout: :infinity

    defrpc(:say_hello)
    defrpc(:to_list, args: 2, as: :list)
    defrpc(:raise_runtime, as: :safe_raise, error_handling: true)
  end

  ## ---- Basic function wrapping ----

  describe "zero-arg function" do
    test "returns expected atom" do
      assert BasicWrapper.say_hello() == :hello
    end
  end

  describe "single-arg function" do
    test "echoes any value" do
      assert BasicWrapper.echo(42) == 42
      assert BasicWrapper.echo("str") == "str"
    end

    test "renamed via :as" do
      assert BasicWrapper.greet("Alice") == "Hello, Alice"
    end
  end

  describe "multi-arg functions" do
    test "integer arity (args: 2)" do
      assert BasicWrapper.make_list(:a, :b) == [:a, :b]
    end

    test "named arg list (args: [:first, :second])" do
      assert BasicWrapper.pair(:x, :y) == {:x, :y}
    end
  end

  ## ---- Private functions ----

  describe "private function generation" do
    test "private function is NOT exported" do
      assert_raise UndefinedFunctionError, fn ->
        apply(BasicWrapper, :private_list, [:a, :b])
      end
    end

    test "private function IS callable from within the module" do
      assert BasicWrapper.call_private(:a, :b) == [:a, :b]
    end
  end

  ## ---- Error handling ----

  describe "error_handling: true" do
    test "returns {:error, %EasyRpc.Error{}} on exception" do
      assert {:error, %EasyRpc.Error{}} = BasicWrapper.safe_raise()
    end

    test "error message contains exception details" do
      {:error, err} = BasicWrapper.safe_raise()
      assert err.message =~ "runtime error"
    end
  end

  describe "no error handling (default)" do
    test "raises ErlangError on remote exception" do
      assert_raise ErlangError, fn -> BasicWrapper.bare_raise() end
    end

    test "raises ErlangError when arg triggers exception" do
      assert_raise ErlangError, fn -> BasicWrapper.raise_arg("oops") end
    end
  end

  ## ---- Retry ----

  describe "retry (retry: 2)" do
    test "returns {:error, _} after retries exhausted" do
      assert {:error, _} = BasicWrapper.retry_raise()
    end
  end

  ## ---- MFA node selector ----

  describe "MFA-based dynamic node resolution" do
    test "executes successfully with MFA nodes" do
      assert MfaWrapper.say_hello() == :hello
    end

    test "multi-arg function works via MFA nodes" do
      assert MfaWrapper.list(1, 2) == [1, 2]
    end

    test "error_handling works with MFA nodes" do
      assert {:error, _} = MfaWrapper.safe_raise()
    end
  end

  ## ---- Compile-time validation ----

  describe "compile-time validation" do
    test "missing :otp_app raises KeyError at module definition" do
      assert_raise KeyError, fn ->
        defmodule BadDefRpc1 do
          use DefRpc,
            config_name: :dr_basic,
            module: String
        end
      end
    end

    test "missing :module raises EasyRpc.Error at module definition" do
      assert_raise EasyRpc.Error, fn ->
        defmodule BadDefRpc2 do
          use DefRpc,
            otp_app: :easy_rpc_test,
            config_name: :dr_basic
        end
      end
    end
  end
end
