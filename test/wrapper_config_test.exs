defmodule EasyRpc.WrapperConfigTest do
  use ExUnit.Case

  alias EasyRpc.{WrapperConfig, NodeSelector, Error}

  @nodes [Node.self()]

  def get_node, do: @nodes

  setup_all do
    Application.put_env(:easy_rpc_test, :wc_basic,
      nodes: @nodes,
      module: DateTime,
      functions: [
        {:utc_now, 0},
        {:to_string, 1, [new_name: :to_string_new]},
        {:diff, 3, [private: true]}
      ]
    )

    Application.put_env(:easy_rpc_test, :wc_full,
      nodes: @nodes,
      module: String,
      error_handling: true,
      retry: 2,
      timeout: 3_000,
      functions: [
        {:upcase, 1},
        {:downcase, 1, [retry: 5]}
      ]
    )

    Application.put_env(:easy_rpc_test, :wc_mfa,
      nodes: {__MODULE__, :get_node, []},
      module: String,
      functions: []
    )

    :ok
  end

  ## ---- load_config!/2 ----

  describe "load_config!/2" do
    test "loads module" do
      config = WrapperConfig.load_config!(:easy_rpc_test, :wc_basic)
      assert config.module == DateTime
    end

    test "uses default timeout/retry/error_handling when absent from config" do
      config = WrapperConfig.load_config!(:easy_rpc_test, :wc_basic)
      assert config.timeout == 5_000
      assert config.retry == 0
      assert config.error_handling == false
    end

    test "loads explicit timeout, retry, error_handling" do
      config = WrapperConfig.load_config!(:easy_rpc_test, :wc_full)
      assert config.timeout == 3_000
      assert config.retry == 2
      assert config.error_handling == true
    end

    test "loads functions list" do
      config = WrapperConfig.load_config!(:easy_rpc_test, :wc_basic)
      assert length(config.functions) == 3
    end

    test "builds NodeSelector from same config key" do
      config = WrapperConfig.load_config!(:easy_rpc_test, :wc_basic)
      assert %NodeSelector{} = config.node_selector
    end

    test "loads MFA-based node selector" do
      config = WrapperConfig.load_config!(:easy_rpc_test, :wc_mfa)
      assert config.node_selector.nodes_or_mfa == {__MODULE__, :get_node, []}
    end

    test "raises when config key is missing" do
      assert_raise Error, fn ->
        WrapperConfig.load_config!(:easy_rpc_test, :wc_missing)
      end
    end
  end

  ## ---- load_from_options!/1 ----

  describe "load_from_options!/1" do
    test "creates config from full options" do
      selector = NodeSelector.new(@nodes, :test_opts)

      config =
        WrapperConfig.load_from_options!(
          node_selector: selector,
          module: String,
          timeout: 2_000,
          retry: 1,
          error_handling: true
        )

      assert config.module == String
      assert config.timeout == 2_000
      assert config.retry == 1
      assert config.error_handling == true
    end

    test "optional fields default correctly" do
      config = WrapperConfig.load_from_options!(module: String)
      assert config.node_selector == nil
      assert config.timeout == 5_000
      assert config.retry == 0
      assert config.error_handling == false
      assert config.functions == []
    end

    test "raises when :module key is missing" do
      assert_raise Error, ~r/:module/i, fn ->
        WrapperConfig.load_from_options!(timeout: 1_000)
      end
    end
  end

  ## ---- new!/2-5 ----

  describe "new!/2" do
    test "applies all defaults" do
      sel = NodeSelector.new(@nodes, :id)
      config = WrapperConfig.new!(sel, String)
      assert config.timeout == 5_000
      assert config.retry == 0
      assert config.error_handling == false
      assert config.functions == []
    end
  end

  describe "new!/3" do
    test "sets timeout" do
      sel = NodeSelector.new(@nodes, :id)
      config = WrapperConfig.new!(sel, String, 10_000)
      assert config.timeout == 10_000
    end

    test "accepts :infinity timeout" do
      sel = NodeSelector.new(@nodes, :id)
      config = WrapperConfig.new!(sel, String, :infinity)
      assert config.timeout == :infinity
    end
  end

  describe "new!/4" do
    test "sets timeout and retry" do
      sel = NodeSelector.new(@nodes, :id)
      config = WrapperConfig.new!(sel, String, 5_000, 3)
      assert config.retry == 3
    end
  end

  describe "new!/5" do
    test "sets all explicit fields" do
      sel = NodeSelector.new(@nodes, :id)
      config = WrapperConfig.new!(sel, String, 1_000, 5, true)
      assert config.timeout == 1_000
      assert config.retry == 5
      assert config.error_handling == true
    end
  end

  ## ---- validate!/1 — error cases ----

  describe "validate!/1 — invalid values" do
    test "raises on nil module" do
      assert_raise Error, ~r/Invalid module/i, fn ->
        WrapperConfig.new!(NodeSelector.new(@nodes, :id), nil)
      end
    end

    test "raises on non-positive timeout" do
      assert_raise Error, ~r/Invalid timeout/i, fn ->
        WrapperConfig.new!(NodeSelector.new(@nodes, :id), String, -1)
      end
    end

    test "raises on zero timeout" do
      assert_raise Error, ~r/Invalid timeout/i, fn ->
        WrapperConfig.new!(NodeSelector.new(@nodes, :id), String, 0)
      end
    end

    test "raises on negative retry count" do
      assert_raise Error, ~r/Invalid retry/i, fn ->
        WrapperConfig.new!(NodeSelector.new(@nodes, :id), String, 5_000, -1)
      end
    end

    test "raises on invalid node_selector value" do
      assert_raise Error, ~r/Invalid node_selector/i, fn ->
        WrapperConfig.load_from_options!(module: String, node_selector: "bad")
      end
    end
  end

  ## ---- validate!/1 — function specs ----

  describe "validate!/1 — function spec validation" do
    test "accepts 2-tuple spec" do
      config = WrapperConfig.load_from_options!(module: String, functions: [{:upcase, 1}])
      assert length(config.functions) == 1
    end

    test "accepts 3-tuple spec with valid opts" do
      config =
        WrapperConfig.load_from_options!(
          module: String,
          functions: [{:upcase, 1, [new_name: :upper, retry: 2, timeout: 1_000]}]
        )

      assert length(config.functions) == 1
    end

    test "raises on invalid spec format (bare atom)" do
      assert_raise Error, fn ->
        WrapperConfig.load_from_options!(module: String, functions: [:bad])
      end
    end

    test "raises on negative arity" do
      assert_raise Error, fn ->
        WrapperConfig.load_from_options!(module: String, functions: [{:fun, -1}])
      end
    end

    test "raises on unknown function option key" do
      assert_raise Error, fn ->
        WrapperConfig.load_from_options!(module: String, functions: [{:fun, 1, [bad_opt: true]}])
      end
    end

    test "raises on invalid timeout in function opts" do
      assert_raise Error, fn ->
        WrapperConfig.load_from_options!(module: String, functions: [{:fun, 1, [timeout: -1]}])
      end
    end

    test "raises on invalid retry in function opts" do
      assert_raise Error, fn ->
        WrapperConfig.load_from_options!(module: String, functions: [{:fun, 1, [retry: -1]}])
      end
    end
  end
end
