defmodule EasyRpc.WrapperConfig do
  @moduledoc """
  Configuration struct for RPC wrappers.

  Used by both `EasyRpc.RpcWrapper` and `EasyRpc.DefRpc` to describe how
  remote calls are executed.

  ## Fields

  - `node_selector`   - `NodeSelector` for picking target nodes
  - `module`          - Remote module to call (required)
  - `timeout`         - RPC timeout in ms, or `:infinity` (default: `5_000`)
  - `retry`           - Retry attempts on failure (default: `0`)
  - `error_handling`  - Return `{:ok, _} | {:error, _}` tuples (default: `false`)
  - `functions`       - Function specs used by `RpcWrapper` (default: `[]`)

  ## Function Specs

      {name, arity}
      {name, arity, opts}

  Per-function opts: `:new_name`, `:as`, `:retry`, `:timeout`,
  `:error_handling`, `:private`.

  ## Examples

      WrapperConfig.load_from_options!(
        node_selector: selector,
        module: RemoteModule,
        timeout: 5_000,
        retry: 3,
        error_handling: true
      )
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
  Loads config from the application environment.

  Expected format:

      config :my_app, :rpc_config,
        nodes: [:node1@host],
        select_mode: :random,
        module: RemoteModule,
        timeout: 5_000,
        retry: 3,
        error_handling: true,
        functions: [{:func_name, 1}]

  Raises `EasyRpc.Error` if config is missing or invalid.
  """
  @spec load_config!(app :: atom(), config_name :: atom()) :: t()
  def load_config!(app_name, config_name) do
    config = Application.get_env(app_name, config_name)

    unless config do
      Error.raise!(
        :config_error,
        "WrapperConfig not found: #{inspect(app_name)}.#{inspect(config_name)}"
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
  Loads config from a keyword list.

  Raises `EasyRpc.Error` on missing `:module` or invalid values.
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
      Error.raise!(:config_error, "Missing required :module key in options")
  end

  @doc "Creates a validated `WrapperConfig` with explicit parameters."
  @spec new!(NodeSelector.t(), module()) :: t()
  def new!(node_selector, module),
    do: new!(node_selector, module, 5_000, 0, false)

  @spec new!(NodeSelector.t(), module(), pos_integer() | :infinity) :: t()
  def new!(node_selector, module, timeout),
    do: new!(node_selector, module, timeout, 0, false)

  @spec new!(NodeSelector.t(), module(), pos_integer() | :infinity, non_neg_integer()) :: t()
  def new!(node_selector, module, timeout, retry),
    do: new!(node_selector, module, timeout, retry, false)

  @spec new!(NodeSelector.t(), module(), pos_integer() | :infinity, non_neg_integer(), boolean()) ::
          t()
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
  Validates a `WrapperConfig` struct. Called automatically by all constructors.
  Raises `EasyRpc.Error` on any invalid field.
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

  ## Private Validators

  defp validate_node_selector!(%NodeSelector{}), do: :ok
  defp validate_node_selector!(nil), do: :ok

  defp validate_node_selector!(invalid),
    do:
      Error.raise!(
        :config_error,
        "Invalid node_selector — expected %NodeSelector{} or nil, got: #{inspect(invalid)}"
      )

  defp validate_module!(m) when is_atom(m) and not is_nil(m), do: :ok

  defp validate_module!(invalid),
    do:
      Error.raise!(
        :config_error,
        "Invalid module — expected a non-nil atom, got: #{inspect(invalid)}"
      )

  defp validate_timeout!(:infinity), do: :ok
  defp validate_timeout!(t) when is_integer(t) and t > 0, do: :ok

  defp validate_timeout!(invalid),
    do:
      Error.raise!(
        :config_error,
        "Invalid timeout — expected positive integer or :infinity, got: #{inspect(invalid)}"
      )

  defp validate_retry!(r) when is_integer(r) and r >= 0, do: :ok

  defp validate_retry!(invalid),
    do:
      Error.raise!(
        :config_error,
        "Invalid retry — expected non-negative integer, got: #{inspect(invalid)}"
      )

  defp validate_error_handling!(v) when is_boolean(v), do: :ok

  defp validate_error_handling!(invalid),
    do:
      Error.raise!(
        :config_error,
        "Invalid error_handling — expected boolean, got: #{inspect(invalid)}"
      )

  defp validate_functions!(fns) when is_list(fns),
    do: Enum.each(fns, &validate_function_spec!/1)

  defp validate_functions!(invalid),
    do: Error.raise!(:config_error, "Invalid functions — expected list, got: #{inspect(invalid)}")

  defp validate_function_spec!({fun, arity})
       when is_atom(fun) and is_integer(arity) and arity >= 0, do: :ok

  defp validate_function_spec!({fun, arity, opts})
       when is_atom(fun) and is_integer(arity) and arity >= 0 do
    unless Keyword.keyword?(opts) do
      Error.raise!(
        :config_error,
        "Invalid options for #{inspect(fun)}/#{arity} — expected keyword list, got: #{inspect(opts)}"
      )
    end

    validate_function_opts!(opts, fun, arity)
  end

  defp validate_function_spec!(invalid),
    do:
      Error.raise!(
        :config_error,
        "Invalid function spec — expected {atom, arity} or {atom, arity, keyword}, got: #{inspect(invalid)}"
      )

  @valid_fun_keys [:new_name, :as, :retry, :timeout, :error_handling, :private]

  defp validate_function_opts!(opts, fun, arity) do
    Enum.each(opts, fn {key, value} ->
      unless key in @valid_fun_keys do
        Error.raise!(
          :config_error,
          "Unknown option #{inspect(key)} for #{inspect(fun)}/#{arity} — valid: #{inspect(@valid_fun_keys)}"
        )
      end

      validate_function_opt!(key, value, fun, arity)
    end)
  end

  defp validate_function_opt!(:new_name, v, _, _) when is_atom(v), do: :ok
  defp validate_function_opt!(:as, v, _, _) when is_atom(v), do: :ok
  defp validate_function_opt!(:retry, v, _, _) when is_integer(v) and v >= 0, do: :ok
  defp validate_function_opt!(:timeout, :infinity, _, _), do: :ok
  defp validate_function_opt!(:timeout, v, _, _) when is_integer(v) and v > 0, do: :ok
  defp validate_function_opt!(:error_handling, v, _, _) when is_boolean(v), do: :ok
  defp validate_function_opt!(:private, v, _, _) when is_boolean(v), do: :ok

  defp validate_function_opt!(key, value, fun, arity),
    do:
      Error.raise!(
        :config_error,
        "Invalid value for #{inspect(key)} in #{inspect(fun)}/#{arity}: #{inspect(value)}"
      )
end
