defmodule EasyRpc.DefRpcTest do
  use ExUnit.Case

  alias EasyRpc.DefRpc

 #doctest DefRpc

  defmodule MyModule do
    def raise_an_error() do
      raise "An error"
    end

    def raise_with_param(n) do
        raise "An other error, #{inspect n}"
    end

    def say_hello() do
      :hello
    end

    def greeting(name) do
      name
    end

    def to_list(first, second) do
      [first, second]
    end
  end

  alias EasyRpc.DefRpcTest.MyModule

  setup_all do
    setup_config()
    {:ok, state: :ok}
  end

  defp setup_config do
    config1 =
      [
        nodes: [Node.self()],
        select_mode: :random,
      ]
    config2 =
      [
        nodes: Node.self(),
      ]
    config3 =
      [
        nodes: {__MODULE__, :get_node, []},
      ]

    Application.put_env(:easy_rpc_test, :config1, config1)
    Application.put_env(:easy_rpc_test, :config2, config2)
    Application.put_env(:easy_rpc_test, :config3, config3)
  end

  test "test config 1" do
    IO.puts "Test config:"
    IO.puts inspect(Application.get_env(:easy_rpc_test, :config1))

    defmodule WrappedModule do
      use EasyRpc.DefRpc,
        otp_app: :easy_rpc_test,
        config_name: :config1,
        # Remote module name
        module: EasyRpc.DefRpcTest.MyModule,
        timeout: :infinity

      defrpc :say_hello
      defrpc :greeting, args: 1, as: :return_param
      defrpc :to_list, args: [:first, :second], as: :list
      defrpc :to_list, args: 2, as: :my_list, private: true
      defrpc :raise_an_error, as: :test_error, error_handling: true
      defrpc :raise_an_error, as: :test_retry, retry: 3
      defrpc :raise_with_param, args: 1, as: :raise_with_param
      defrpc :raise_an_error, as: :raise_no_error_handling

      def call_private(a, b) do
        my_list(a, b)
      end
    end

    assert WrappedModule.say_hello() == :hello
    assert WrappedModule.return_param("Alice") == "Alice"
    assert WrappedModule.list("Alice", "Bob") == ["Alice", "Bob"]
    assert WrappedModule.call_private("Alice", "Bob") == ["Alice", "Bob"]

    result =
      case WrappedModule.test_error() do
        {:error, _} ->
          :ok
        _ ->
          :incorrect_result
        end
    assert result == :ok

    result =
      case WrappedModule.test_retry() do
        {:error, _} ->
          :ok
        _ ->
          :incorrect_result
        end
    assert result == :ok

    assert_raise ErlangError, fn ->
      WrappedModule.raise_no_error_handling()
    end
  end

  test "test config 2" do
    IO.puts "Test config:"
    IO.puts inspect(Application.get_env(:easy_rpc_test, :config2))

    defmodule WrappedModule do
      use EasyRpc.DefRpc,
        otp_app: :easy_rpc_test,
        config_name: :config1,
        # Remote module name
        module: EasyRpc.DefRpcTest.MyModule,
        timeout: :infinity

      defrpc :say_hello
      defrpc :greeting, args: 1, as: :return_param
      defrpc :to_list, args: [:first, :second], as: :list
      defrpc :to_list, args: 2, as: :my_list, private: true
      defrpc :raise_an_error, as: :test_error, error_handling: true
      defrpc :raise_an_error, as: :test_retry, retry: 3
      defrpc :raise_with_param, args: 1, as: :raise_with_param
      defrpc :raise_an_error, as: :raise_no_error_handling

      def call_private(a, b) do
        my_list(a, b)
      end
    end

    assert WrappedModule.say_hello() == :hello
    assert WrappedModule.return_param("Alice") == "Alice"
    assert WrappedModule.list("Alice", "Bob") == ["Alice", "Bob"]
    assert WrappedModule.call_private("Alice", "Bob") == ["Alice", "Bob"]

    result =
      case WrappedModule.test_error() do
        {:error, _} ->
          :ok
        _ ->
          :incorrect_result
        end
    assert result == :ok

    result =
      case WrappedModule.test_retry() do
        {:error, _} ->
          :ok
        _ ->
          :incorrect_result
        end
    assert result == :ok

    assert_raise ErlangError, fn ->
      WrappedModule.raise_no_error_handling()
    end
  end

  test "test config 3" do
    IO.puts "Test config:"
    IO.puts inspect(Application.get_env(:easy_rpc_test, :config3))

    defmodule WrappedModule do
      use EasyRpc.DefRpc,
        otp_app: :easy_rpc_test,
        config_name: :config1,
        # Remote module name
        module: EasyRpc.DefRpcTest.MyModule,
        timeout: :infinity

      defrpc :say_hello
      defrpc :greeting, args: 1, as: :return_param
      defrpc :to_list, args: [:first, :second], as: :list
      defrpc :to_list, args: 2, as: :my_list, private: true
      defrpc :raise_an_error, as: :test_error, error_handling: true
      defrpc :raise_an_error, as: :test_retry, retry: 3
      defrpc :raise_with_param, args: 1, as: :raise_with_param
      defrpc :raise_an_error, as: :raise_no_error_handling

      def call_private(a, b) do
        my_list(a, b)
      end
    end

    assert WrappedModule.say_hello() == :hello
    assert WrappedModule.return_param("Alice") == "Alice"
    assert WrappedModule.list("Alice", "Bob") == ["Alice", "Bob"]
    assert WrappedModule.call_private("Alice", "Bob") == ["Alice", "Bob"]

    result =
      case WrappedModule.test_error() do
        {:error, _} ->
          :ok
        _ ->
          :incorrect_result
        end
    assert result == :ok

    result =
      case WrappedModule.test_retry() do
        {:error, _} ->
          :ok
        _ ->
          :incorrect_result
        end
    assert result == :ok

    assert_raise ErlangError, fn ->
      WrappedModule.raise_no_error_handling()
    end
  end

end
