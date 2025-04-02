defmodule EasyRpc.RpcWrapperTest do
  use ExUnit.Case

  doctest EasyRpc

  alias EasyRpc.RpcWrapper

  doctest RpcWrapper

  setup_all do
    setup_config()
    {:ok, state: :ok}
  end

  defp setup_config do
    config1 =
      [
        nodes: [Node.self()],
        module: DateTime,
        functions: [
          {:utc_now, 0},
          {:to_string, 1, new_name: :to_string_new},
          {:diff, 3, private: true}
        ],
        nodes: [Node.self()]
      ]
    config2 =
      [
        nodes: [Node.self()],
        module: MyModule,
        error_handling: false,
        functions: [
          {:raise_an_error, 0},
          {:raise_an_error, 0, new_name: :test_error, error_handling: true},
          {:retry_me, 1, new_name: :test_retry, retry: 3},
        ],

      ]

    Application.put_env(:easy_rpc_test, :config1, config1)
    Application.put_env(:easy_rpc_test, :config2, config2)
  end

  @tag :test_1
  test "wrap a local module test" do
    IO.puts "Test config:"
    IO.puts inspect(Application.get_env(:easy_rpc_test, :config1))

    defmodule Wrapper do
      use RpcWrapper,
        otp_app: :easy_rpc_test,
        config_name: :config1
    end

    result =
      case Wrapper.utc_now() do
        %DateTime{} ->
          :ok
        _ ->
          :incorrect_result
        end
    assert result == :ok

    now = DateTime.utc_now()
    assert Wrapper.to_string_new(now) == DateTime.to_string(now)

    assert_raise UndefinedFunctionError, fn ->
      Wrapper.diff(now, now, :second)
    end
  end

  test "test wrap with retry & error" do
    defmodule MyModule do
      def raise_an_error() do
        raise "An error"
      end

      def retry_me(n) do
          raise "An other error, #{inspect n}"
      end
    end

    IO.puts "Test config:"
    IO.puts inspect(Application.get_env(:easy_rpc_test, :config2))

    defmodule Wrapper2 do
      use RpcWrapper,
        otp_app: :easy_rpc_test,
        config_name: :config2
    end

    result =
      case Wrapper2.test_error() do
        {:error, _} ->
          :ok
        _ ->
          :incorrect_result
        end
    assert result == :ok

    result =
      case Wrapper2.test_retry(1) do
        {:error, _} ->
          :ok
        _ ->
          :incorrect_result
        end
    assert result == :ok

    assert_raise ErlangError, fn ->
      Wrapper2.raise_an_error()
    end
  end
end
