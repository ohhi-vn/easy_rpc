defmodule EasyRpc.Utils.FunctionGeneratorTest do
  use ExUnit.Case, async: true

  alias EasyRpc.Utils.FunctionGenerator
  alias EasyRpc.{WrapperConfig, Error}

  @base_config %WrapperConfig{
    node_selector: nil,
    module: SomeMod,
    timeout: 5_000,
    retry: 0,
    error_handling: false,
    functions: []
  }

  ## ---- normalize_function_info/1 ----

  describe "normalize_function_info/1" do
    test "2-tuple produces {name, arity, []}" do
      assert FunctionGenerator.normalize_function_info({:get, 1}) == {:get, 1, []}
    end

    test "3-tuple is returned unchanged" do
      input = {:get, 1, [retry: 3]}
      assert FunctionGenerator.normalize_function_info(input) == input
    end

    test "3-tuple with empty opts list is valid" do
      assert FunctionGenerator.normalize_function_info({:get, 2, []}) == {:get, 2, []}
    end

    test "bare atom raises Error" do
      assert_raise Error, fn -> FunctionGenerator.normalize_function_info(:get) end
    end

    test "non-integer arity raises Error" do
      assert_raise Error, fn -> FunctionGenerator.normalize_function_info({:get, "1"}) end
    end

    test "non-atom name raises Error" do
      assert_raise Error, fn -> FunctionGenerator.normalize_function_info({"get", 1}) end
    end
  end

  ## ---- resolve_function_name/2 ----

  describe "resolve_function_name/2" do
    test "returns original name when no override provided" do
      assert FunctionGenerator.resolve_function_name(:get_user, []) == :get_user
    end

    test ":as option overrides name" do
      assert FunctionGenerator.resolve_function_name(:get_user, as: :fetch_user) == :fetch_user
    end

    test ":new_name option overrides name" do
      assert FunctionGenerator.resolve_function_name(:get_user, new_name: :find_user) ==
               :find_user
    end

    test ":as takes precedence over :new_name when both present" do
      result = FunctionGenerator.resolve_function_name(:get_user, as: :a, new_name: :b)
      assert result == :a
    end
  end

  ## ---- is_private?/1 ----

  describe "is_private?/1" do
    test "returns false when :private not specified" do
      assert FunctionGenerator.is_private?([]) == false
    end

    test "returns true when private: true" do
      assert FunctionGenerator.is_private?(private: true) == true
    end

    test "returns false when private: false" do
      assert FunctionGenerator.is_private?(private: false) == false
    end
  end

  ## ---- merge_config/2 ----

  describe "merge_config/2" do
    test "returns global defaults when no opts override them" do
      merged = FunctionGenerator.merge_config(@base_config, [])
      assert merged.retry == 0
      assert merged.timeout == 5_000
      assert merged.error_handling == false
    end

    test "overrides retry from fun_opts" do
      merged = FunctionGenerator.merge_config(@base_config, retry: 3)
      assert merged.retry == 3
    end

    test "overrides timeout from fun_opts" do
      merged = FunctionGenerator.merge_config(@base_config, timeout: 1_000)
      assert merged.timeout == 1_000
    end

    test "overrides error_handling from fun_opts" do
      merged = FunctionGenerator.merge_config(@base_config, error_handling: true)
      assert merged.error_handling == true
    end

    test "auto-enables error_handling when fun retry > 0" do
      config = %{@base_config | error_handling: false}
      merged = FunctionGenerator.merge_config(config, retry: 2)
      assert merged.error_handling == true
    end

    test "auto-enables error_handling when global retry > 0 and no fun override" do
      config = %{@base_config | retry: 1, error_handling: false}
      merged = FunctionGenerator.merge_config(config, [])
      assert merged.error_handling == true
    end

    test "does not touch error_handling when retry remains 0" do
      merged = FunctionGenerator.merge_config(@base_config, retry: 0, error_handling: false)
      assert merged.error_handling == false
    end

    test "preserves unrelated config fields" do
      merged = FunctionGenerator.merge_config(@base_config, retry: 1)
      assert merged.module == @base_config.module
      assert merged.node_selector == @base_config.node_selector
      assert merged.functions == @base_config.functions
    end
  end

  ## ---- parse_arity/1 ----

  describe "parse_arity/1" do
    test "integer 0 returns 0" do
      assert FunctionGenerator.parse_arity(0) == 0
    end

    test "empty list returns 0" do
      assert FunctionGenerator.parse_arity([]) == 0
    end

    test "positive integer is returned as-is" do
      assert FunctionGenerator.parse_arity(5) == 5
    end

    test "list of atoms is returned as-is" do
      assert FunctionGenerator.parse_arity([:user_id, :name]) == [:user_id, :name]
    end

    test "list with non-atoms raises Error" do
      assert_raise Error, fn -> FunctionGenerator.parse_arity([:user_id, "name"]) end
    end

    test "negative integer raises Error" do
      assert_raise Error, fn -> FunctionGenerator.parse_arity(-1) end
    end

    test "string raises Error" do
      assert_raise Error, fn -> FunctionGenerator.parse_arity("one") end
    end

    test "atom raises Error" do
      assert_raise Error, fn -> FunctionGenerator.parse_arity(:one) end
    end
  end

  ## ---- generate_arg_vars/1 ----

  describe "generate_arg_vars/1" do
    test "0 returns empty list" do
      assert FunctionGenerator.generate_arg_vars(0) == []
    end

    test "positive integer N returns N AST variable nodes" do
      vars = FunctionGenerator.generate_arg_vars(3)
      assert length(vars) == 3
      assert Enum.all?(vars, &match?({_, _, nil}, &1))
    end

    test "integer vars are named arg_1..arg_N" do
      vars = FunctionGenerator.generate_arg_vars(2)
      names = Enum.map(vars, fn {name, _, _} -> name end)
      assert names == [:arg_1, :arg_2]
    end

    test "list of atoms returns vars with matching names" do
      vars = FunctionGenerator.generate_arg_vars([:user_id, :email])
      names = Enum.map(vars, fn {name, _, _} -> name end)
      assert names == [:user_id, :email]
    end
  end

  ## ---- validate_function_opts!/1 ----

  describe "validate_function_opts!/1" do
    test "all valid keys pass without error" do
      opts = [as: :x, new_name: :y, retry: 2, timeout: 500, error_handling: true, private: false]
      assert FunctionGenerator.validate_function_opts!(opts) == :ok
    end

    test "timeout :infinity is valid" do
      assert FunctionGenerator.validate_function_opts!(timeout: :infinity) == :ok
    end

    test "empty opts list passes" do
      assert FunctionGenerator.validate_function_opts!([]) == :ok
    end

    test "unknown key raises Error" do
      assert_raise Error, fn -> FunctionGenerator.validate_function_opts!(unknown: true) end
    end

    test "negative retry raises Error" do
      assert_raise Error, fn -> FunctionGenerator.validate_function_opts!(retry: -1) end
    end

    test "zero timeout raises Error" do
      assert_raise Error, fn -> FunctionGenerator.validate_function_opts!(timeout: 0) end
    end

    test "non-boolean private raises Error" do
      assert_raise Error, fn -> FunctionGenerator.validate_function_opts!(private: "yes") end
    end
  end
end
