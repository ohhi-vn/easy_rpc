defmodule EasyRpc.Utils.FunctionGenerator do
  @moduledoc """
  Utilities for generating RPC wrapper functions.

  This module provides helper functions used by both `EasyRpc.RpcWrapper`
  and `EasyRpc.DefRpc` to generate wrapper functions with consistent behavior.

  It handles:
  - Function option parsing and validation
  - Merging global and per-function configurations
  - Function name resolution
  - Arity handling

  ## Function Options

  Supported options for individual functions:
  - `:as` / `:new_name` - Alternative name for the generated function
  - `:retry` - Number of retry attempts (overrides global setting)
  - `:timeout` - Timeout in milliseconds (overrides global setting)
  - `:error_handling` - Enable/disable error handling (overrides global setting)
  - `:private` - Generate as private function (default: false)
  """

  alias EasyRpc.WrapperConfig

  @type function_opts :: keyword()
  @type function_info :: {name :: atom(), arity :: non_neg_integer(), opts :: keyword()}

  @doc """
  Normalizes function info into a consistent format.

  Converts various function specification formats into a standardized
  tuple of `{function_name, arity, options}`.

  ## Examples

      iex> normalize_function_info({:get_user, 1})
      {:get_user, 1, []}

      iex> normalize_function_info({:get_user, 1, [retry: 3]})
      {:get_user, 1, [retry: 3]}

  ## Raises

  `EasyRpc.Error` if the function info format is invalid
  """
  @spec normalize_function_info(tuple()) :: function_info()
  def normalize_function_info({fun, arity}) when is_atom(fun) and is_integer(arity) do
    {fun, arity, []}
  end

  def normalize_function_info({fun, arity, opts})
      when is_atom(fun) and is_integer(arity) and is_list(opts) do
    {fun, arity, opts}
  end

  def normalize_function_info(invalid) do
    raise EasyRpc.Error.config_error(
            "Invalid function info format: #{inspect(invalid)}. " <>
              "Expected {atom, integer} or {atom, integer, keyword}"
          )
  end

  @doc """
  Resolves the final function name from options.

  Checks for `:as` or `:new_name` options and returns the appropriate name.
  Falls back to the original function name if no override is specified.

  ## Examples

      iex> resolve_function_name(:get_user, [])
      :get_user

      iex> resolve_function_name(:get_user, [as: :fetch_user])
      :fetch_user

      iex> resolve_function_name(:get_user, [new_name: :fetch_user])
      :fetch_user
  """
  @spec resolve_function_name(atom(), function_opts()) :: atom()
  def resolve_function_name(original_name, opts) do
    Keyword.get(opts, :as) || Keyword.get(opts, :new_name, original_name)
  end

  @doc """
  Determines if the function should be generated as private.

  ## Examples

      iex> is_private?([private: true])
      true

      iex> is_private?([])
      false
  """
  @spec is_private?(function_opts()) :: boolean()
  def is_private?(opts) do
    Keyword.get(opts, :private, false)
  end

  @doc """
  Merges global config with function-specific options.

  Creates a new WrapperConfig with function-specific values overriding
  global defaults. Automatically enables error_handling if retry > 0.

  ## Parameters

  - `global_config` - The global WrapperConfig
  - `fun_opts` - Function-specific options

  ## Returns

  A new WrapperConfig with merged settings

  ## Examples

      global_config = %WrapperConfig{retry: 0, timeout: 5000, error_handling: false}

      merge_config(global_config, [retry: 3, timeout: 1000])
      #=> %WrapperConfig{retry: 3, timeout: 1000, error_handling: true}

      merge_config(global_config, [error_handling: false])
      #=> %WrapperConfig{retry: 0, timeout: 5000, error_handling: false}
  """
  @spec merge_config(WrapperConfig.t(), function_opts()) :: WrapperConfig.t()
  def merge_config(%WrapperConfig{} = global_config, fun_opts) do
    fun_retry = Keyword.get(fun_opts, :retry, global_config.retry)
    fun_timeout = Keyword.get(fun_opts, :timeout, global_config.timeout)

    # Always use error_handling if retry > 0
    fun_error_handling =
      if fun_retry > 0 do
        true
      else
        Keyword.get(fun_opts, :error_handling, global_config.error_handling)
      end

    %{global_config | retry: fun_retry, timeout: fun_timeout, error_handling: fun_error_handling}
  end

  @doc """
  Validates function options.

  Ensures that all option keys are valid and values are of the correct type.

  ## Valid Options

  - `:as` / `:new_name` - atom
  - `:retry` - non-negative integer
  - `:timeout` - positive integer or :infinity
  - `:error_handling` - boolean
  - `:private` - boolean
  - `:args` - non-negative integer or list of atoms

  ## Examples

      iex> validate_function_opts!([retry: 3, timeout: 1000])
      :ok

      iex> validate_function_opts!([invalid_option: true])
      ** (EasyRpc.Error) Invalid function option: :invalid_option

  ## Raises

  `EasyRpc.Error` if validation fails
  """
  @spec validate_function_opts!(function_opts()) :: :ok
  def validate_function_opts!(opts) when is_list(opts) do
    valid_keys = [:as, :new_name, :retry, :timeout, :error_handling, :private, :args]

    Enum.each(opts, fn {key, value} ->
      unless key in valid_keys do
        raise EasyRpc.Error.config_error(
                "Invalid function option: #{inspect(key)}. " <>
                  "Valid options: #{inspect(valid_keys)}"
              )
      end

      validate_function_opt_value!(key, value)
    end)

    :ok
  end

  @doc """
  Parses the arity specification.

  Handles different arity formats:
  - Integer: number of arguments
  - Empty list: no arguments (arity 0)
  - List of atoms: named arguments

  ## Examples

      iex> parse_arity(2)
      2

      iex> parse_arity([])
      0

      iex> parse_arity([:user_id, :name])
      [:user_id, :name]

  ## Raises

  `EasyRpc.Error` if arity format is invalid
  """
  @spec parse_arity(integer() | list()) :: non_neg_integer() | [atom()]
  def parse_arity(0), do: 0
  def parse_arity([]), do: 0
  def parse_arity(n) when is_integer(n) and n > 0, do: n

  def parse_arity(list) when is_list(list) do
    unless Enum.all?(list, &is_atom/1) do
      raise EasyRpc.Error.config_error(
              "Invalid args list: all elements must be atoms, got: #{inspect(list)}"
            )
    end

    list
  end

  def parse_arity(invalid) do
    raise EasyRpc.Error.config_error(
            "Invalid arity specification: #{inspect(invalid)}. " <>
              "Expected non-negative integer or list of atoms"
          )
  end

  @doc """
  Generates variable names for function arguments.

  Creates a list of variable AST nodes for macro generation.

  ## Examples

      iex> generate_arg_vars(3)
      [Macro.var(:arg_1, nil), Macro.var(:arg_2, nil), Macro.var(:arg_3, nil)]

      iex> generate_arg_vars([:user_id, :name])
      [Macro.var(:user_id, nil), Macro.var(:name, nil)]
  """
  @spec generate_arg_vars(non_neg_integer() | [atom()]) :: [Macro.t()]
  def generate_arg_vars(0), do: []

  def generate_arg_vars(n) when is_integer(n) and n > 0 do
    Enum.map(1..n, &Macro.var(:"arg_#{&1}", nil))
  end

  def generate_arg_vars(arg_names) when is_list(arg_names) do
    Enum.map(arg_names, &Macro.var(&1, nil))
  end

  ## Private Functions

  defp validate_function_opt_value!(:as, value) when is_atom(value), do: :ok
  defp validate_function_opt_value!(:new_name, value) when is_atom(value), do: :ok
  defp validate_function_opt_value!(:private, value) when is_boolean(value), do: :ok
  defp validate_function_opt_value!(:error_handling, value) when is_boolean(value), do: :ok

  defp validate_function_opt_value!(:retry, value)
       when is_integer(value) and value >= 0,
       do: :ok

  defp validate_function_opt_value!(:timeout, :infinity), do: :ok

  defp validate_function_opt_value!(:timeout, value)
       when is_integer(value) and value > 0,
       do: :ok

  defp validate_function_opt_value!(:args, value) do
    try do
      parse_arity(value)
      :ok
    rescue
      _ ->
        raise EasyRpc.Error.config_error("Invalid value for :args option: #{inspect(value)}")
    end
  end

  defp validate_function_opt_value!(key, value) do
    raise EasyRpc.Error.config_error(
            "Invalid value for option #{inspect(key)}: #{inspect(value)}"
          )
  end
end
