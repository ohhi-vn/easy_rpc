defmodule EasyRpc.WrapperConfigTest do
  use ExUnit.Case

  alias EasyRpc.{WrapperConfig, NodeSelector}

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
        ]
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
    config3 =
      [
        nodes: {__MODULE__, :get_node, []},
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
    Application.put_env(:easy_rpc_test, :config3, config3)
  end

  test "load config from env" do
    wrapper_config1 = WrapperConfig.load_config!(:easy_rpc_test, :config1)
    assert wrapper_config1.module == DateTime
    wrapper_config2 = WrapperConfig.load_config!(:easy_rpc_test, :config2)
    assert wrapper_config2.module == MyModule
  end

  test "load config from env 3" do
    config = WrapperConfig.load_config!(:easy_rpc_test, :config3)
    assert config.module == MyModule
    assert config.node_selector.nodes_or_mfa == {__MODULE__, :get_node, []}
  end

  test "load config from keyword list" do
    wrapper_config1 = WrapperConfig.load_config!(:easy_rpc_test, :config1)

    config2 =
      [
        node_selector: %NodeSelector{},
        module: DateTime,
        functions: [
          {:utc_now, 0},
          {:to_string, 1, new_name: :to_string_new},
          {:diff, 3, private: true}
        ]
      ]
    wrapper_config2 = WrapperConfig.load_from_options!(config2)


    assert wrapper_config1.module == wrapper_config2.module
    assert wrapper_config1.timeout == wrapper_config2.timeout
    assert wrapper_config1.retry == wrapper_config2.retry
    assert wrapper_config1.error_handling == wrapper_config2.error_handling
    assert wrapper_config1.functions == wrapper_config2.functions
    assert wrapper_config1.module == DateTime
  end

  def get_node do
    [Node.self()]
  end
end
