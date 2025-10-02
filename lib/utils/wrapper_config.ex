defmodule EasyRpc.WrapperConfig do
  @moduledoc """
  Configuration struct for RPC wrappers.

  This module defines the configuration structure used by both `EasyRpc.RpcWrapper`
  and `EasyRpc.DefRpc` for executing remote procedure calls. It handles validation
  of configuration parameters and provides utilities for loading configuration from
  various sources.

  ## Configuration Fields

  - `node_selector` - `NodeSelector` struct for selecting target nodes
  - `module` - Remote module name to call (required)
  - `timeout` - RPC timeout in milliseconds (default: 5000, or :infinity)
  - `retry` - Number of retry attempts on failure (default: 0)
  - `error_handling` - Whether to catch errors and return tuples (default: false)
  - `functions` - List of function specifications for RpcWrapper (default: [])

  ## Function Specifications

  Functions are specified as tuples in one of these formats:

  - `{function_name, arity}` - Basic function spec
  - `{function_name, arity, opts}` - Function with options

  Available options per function:
  - `:new_name` - Alternative name for the local function
  - `:retry` - Override global retry setting
  - `:timeout` - Override global timeout setting
  - `:error_handling` - Override global error handling
  - `:private` - Define as private function (default: false)

  ## Examples

      # Create from keyword list
      config = WrapperConfig.load_from_options!(
        node_selector: node_selector,
        module: RemoteModule,
        timeout: 5_000,
        retry: 3,
        error_handling: true
      )

      # Create directly
      config = WrapperConfig.new!(
        node_selector,
        RemoteModule,
        5_000,
        3,
        true
      )

      # Load from application config
      config = WrapperConfig.load_config!(:my_app, :rpc_config)

  ## Configuration File Example

      config :my_app, :rpc_config,
        nodes: [:node1@host, :node2@host],
        select_mode: :random,
        module: Remote.Api,
        timeout: 5_000,
        retry: 3,
        error_handling: true,
        functions: [
          {:get_user, 1},
          {:create_user, 2, [retry: 5]},
          {:delete_user, 1, [new_name: :remove_user, private: true]}
        ]
  """

  alias EasyRpc.{Error, NodeSelector}
  alias __MODULE__

  @type function_spec ::
          {name :: atom(), arity :: non_neg_integer()}
          | {name :: atom(), arity :: non_neg_integer(), opts :: keyword()}

  @type t :: %__MODULE__{
          node_selector: NodeSelector.t() | nil,
          module: module(),
          timeout: pos_integer() | :infinity,
          retry: non_neg_integer(),
          error_handling: boolean(),
          functions: [function_spec()]
        }

  defstruct [
    :node_selector,
    :module,
    timeout: 5_000,
    retry: 0,
    error_handling: false,
    functions: []
  ]

  ## Public API

  @doc """
  Loads configuration from application config.

  Reads configuration from the application environment and creates a validated
  WrapperConfig struct. The NodeSelector is also loaded from the same config.

  ## Parameters

  - `app_name` - Application name (e.g., `:my_app`)
  - `config_name` - Configuration key (e.g., `:rpc_config`)

  ## Expected Config Format

      config :my_app, :rpc_config,
        nodes: [:node1@host],
        select_mode: :random,
        module: RemoteModule,
        timeout: 5_000,
        retry: 3,
        error_handling: true,
        functions: [{:func_name, 1}]

  ## Examples

      config = WrapperConfig.load_config!(:my_app, :remote_api)

  ## Raises

  `EasyRpc.Error` if configuration is missing or invalid
  """
  @spec load_config!(app :: atom(), config_name :: atom()) :: t()
  def load_config!(app_name, config_name) do
    config = Application.get_env(app_name, config_name)

    unless config do
      Error.raise!(
        :config_error,
        "Configuration not found for #{inspect(app_name)}.#{inspect(config_name)}"
      )
    end

    %WrapperConfig{
      node_selector: NodeSelector.load_config!(app_name, config_name),
      module: Keyword.fetch!(config, :module),
      timeout: Keyword.get(config, :timeout, 5_000),
      retry: Keyword.get(config, :retry, 0),
      error_handling: Keyword.get(config, :error_handling, false),
      functions: Keyword.get(config, :functions, [])
    }
    |> validate!()
  end

  @doc """
  Loads configuration from a keyword list.

  Creates a WrapperConfig from the provided options. Useful for programmatic
  configuration without using application config.

  ## Parameters

  Keyword list with the following keys:
  - `:node_selector` - NodeSelector struct (optional for DefRpc)
  - `:module` - Remote module name (required)
  - `:timeout` - Timeout in ms (default: 5000)
  - `:retry` - Retry attempts (default: 0)
  - `:error_handling` - Enable error handling (default: false)
  - `:functions` - Function list (default: [])

  ## Examples

      config = WrapperConfig.load_from_options!(
        node_selector: selector,
        module: RemoteModule,
        timeout: 3_000,
        retry: 2
      )

  ## Raises

  `EasyRpc.Error` if configuration is invalid
  """
  @spec load_from_options!(keyword()) :: t()
  def load_from_options!(options) when is_list(options) do
    %WrapperConfig{
      node_selector: Keyword.get(options, :node_selector),
      module: Keyword.fetch!(options, :module),
      timeout: Keyword.get(options, :timeout, 5_000),
      retry: Keyword.get(options, :retry, 0),
      error_handling: Keyword.get(options, :error_handling, false),
      functions: Keyword.get(options, :functions, [])
    }
    |> validate!()
  rescue
    KeyError ->
      Error.raise!(
        :config_error,
        "Missing required :module key in options"
      )
  end

  @doc """
  Creates a new WrapperConfig with explicit parameters.

  ## Parameters

  - `node_selector` - NodeSelector struct
  - `module` - Remote module name
  - `timeout` - Timeout in milliseconds (default: 5000)
  - `retry` - Number of retry attempts (default: 0)
  - `error_handling` - Enable error handling (default: false)

  ## Examples

      config = WrapperConfig.new!(
        node_selector,
        RemoteModule
      )

      config = WrapperConfig.new!(
        node_selector,
        RemoteModule,
        10_000,
        3,
        true
      )

  ## Raises

  `EasyRpc.Error` if configuration is invalid
  """
  @spec new!(NodeSelector.t(), module()) :: t()
  def new!(node_selector, module) do
    new!(node_selector, module, 5_000, 0, false)
  end

  @spec new!(NodeSelector.t(), module(), pos_integer() | :infinity) :: t()
  def new!(node_selector, module, timeout) do
    new!(node_selector, module, timeout, 0, false)
  end

  @spec new!(NodeSelector.t(), module(), pos_integer() | :infinity, non_neg_integer()) :: t()
  def new!(node_selector, module, timeout, retry) do
    new!(node_selector, module, timeout, retry, false)
  end

  @spec new!(
          NodeSelector.t(),
          module(),
          pos_integer() | :infinity,
          non_neg_integer(),
          boolean()
        ) :: t()
  def new!(node_selector, module, timeout, retry, error_handling) do
    %WrapperConfig{
      node_selector: node_selector,
      module: module,
      timeout: timeout,
      retry: retry,
      error_handling: error_handling,
      functions: []
    }
    |> validate!()
  end

  @doc """
  Validates a WrapperConfig struct.

  Checks that all configuration values are valid and within expected ranges.
  This is automatically called by `new!/1-5`, `load_config!/2`, and
  `load_from_options!/1`.

  ## Examples

      config = %WrapperConfig{module: MyModule}
      validated = WrapperConfig.validate!(config)

  ## Raises

  `EasyRpc.Error` if any validation fails
  """
  @spec validate!(t()) :: t()
  def validate!(%WrapperConfig{} = config) do
    validate_node_selector!(config.node_selector)
    validate_module!(config.module)
    validate_timeout!(config.timeout)
    validate_retry!(config.retry)
    validate_error_handling!(config.error_handling)
    validate_functions!(config.functions)
    config
  end

  ## Private Validation Functions

  defp validate_node_selector!(%NodeSelector{}), do: :ok
  defp validate_node_selector!(nil), do: :ok

  defp validate_node_selector!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid node_selector. Expected %NodeSelector{} or nil, got: #{inspect(invalid)}"
    )
  end

  defp validate_module!(module) when is_atom(module) and not is_nil(module), do: :ok

  defp validate_module!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid module. Expected non-nil atom, got: #{inspect(invalid)}"
    )
  end

  defp validate_timeout!(:infinity), do: :ok
  defp validate_timeout!(timeout) when is_integer(timeout) and timeout > 0, do: :ok

  defp validate_timeout!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid timeout. Expected positive integer or :infinity, got: #{inspect(invalid)}"
    )
  end

  defp validate_retry!(retry) when is_integer(retry) and retry >= 0, do: :ok

  defp validate_retry!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid retry count. Expected non-negative integer, got: #{inspect(invalid)}"
    )
  end

  defp validate_error_handling!(value) when is_boolean(value), do: :ok

  defp validate_error_handling!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid error_handling. Expected boolean, got: #{inspect(invalid)}"
    )
  end

  defp validate_functions!(functions) when is_list(functions) do
    Enum.each(functions, &validate_function_spec!/1)
  end

  defp validate_functions!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid functions. Expected list, got: #{inspect(invalid)}"
    )
  end

  defp validate_function_spec!({fun, arity})
       when is_atom(fun) and is_integer(arity) and arity >= 0 do
    :ok
  end

  defp validate_function_spec!({fun, arity, opts})
       when is_atom(fun) and is_integer(arity) and arity >= 0 do
    unless Keyword.keyword?(opts) do
      Error.raise!(
        :config_error,
        "Invalid function options for #{inspect(fun)}/#{arity}. Expected keyword list, got: #{inspect(opts)}"
      )
    end

    validate_function_opts!(opts, fun, arity)
  end

  defp validate_function_spec!(invalid) do
    Error.raise!(
      :config_error,
      "Invalid function spec. Expected {atom, non_neg_integer} or {atom, non_neg_integer, keyword}, got: #{inspect(invalid)}"
    )
  end

  defp validate_function_opts!(opts, fun, arity) do
    valid_keys = [:new_name, :retry, :timeout, :error_handling, :private, :as]

    Enum.each(opts, fn {key, value} ->
      unless key in valid_keys do
        Error.raise!(
          :config_error,
          "Invalid option #{inspect(key)} for function #{inspect(fun)}/#{arity}. Valid options: #{inspect(valid_keys)}"
        )
      end

      validate_function_opt!(key, value, fun, arity)
    end)
  end

  defp validate_function_opt!(:new_name, value, _fun, _arity) when is_atom(value), do: :ok
  defp validate_function_opt!(:as, value, _fun, _arity) when is_atom(value), do: :ok

  defp validate_function_opt!(:retry, value, _fun, _arity)
       when is_integer(value) and value >= 0,
       do: :ok

  defp validate_function_opt!(:timeout, :infinity, _fun, _arity), do: :ok

  defp validate_function_opt!(:timeout, value, _fun, _arity)
       when is_integer(value) and value > 0,
       do: :ok

  defp validate_function_opt!(:error_handling, value, _fun, _arity) when is_boolean(value),
    do: :ok

  defp validate_function_opt!(:private, value, _fun, _arity) when is_boolean(value), do: :ok

  defp validate_function_opt!(key, value, fun, arity) do
    Error.raise!(
      :config_error,
      "Invalid value for #{inspect(key)} in function #{inspect(fun)}/#{arity}: #{inspect(value)}"
    )
  end
end
