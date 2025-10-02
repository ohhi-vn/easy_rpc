defmodule EasyRpc.RpcCall do
  @moduledoc """
  Core module for executing remote procedure calls.

  This module handles the actual RPC execution with support for:
  - Error handling and recovery
  - Automatic retries with configurable attempts
  - Node selection strategies
  - Timeout management
  - Detailed logging

  This module implements the `EasyRpc.Behaviours.RpcExecutor` behavior.

  ## Examples

      config = %EasyRpc.WrapperConfig{
        node_selector: node_selector,
        module: RemoteModule,
        timeout: 5_000,
        retry: 3,
        error_handling: true
      }

      # Execute with error handling
      {:ok, result} = EasyRpc.RpcCall.execute(config, :get_data, ["key1"])

      # Execute without error handling (raises on error)
      result = EasyRpc.RpcCall.execute(config, :get_data, ["key1"])

      # Execute with dynamic config
      {:ok, result} = EasyRpc.RpcCall.execute_dynamic(config, {:my_app, :config_name}, :get_data, ["key1"])
  """

  @behaviour EasyRpc.Behaviours.RpcExecutor

  alias :erpc, as: Erpc
  alias EasyRpc.{WrapperConfig, NodeSelector, Error}

  require Logger

  @type function_name :: atom()
  @type args :: list()
  @type result :: {:ok, term()} | {:error, Error.t()}
  @type raw_result :: term()
  @type config_ref :: {app :: atom(), config_name :: atom()}

  ## Public API

  @doc """
  Executes an RPC call with the given configuration.

  Delegates to error handling or non-error handling implementation
  based on the configuration.

  ## Parameters

  - `config` - WrapperConfig struct with execution settings
  - `function` - Remote function name to call
  - `args` - List of arguments for the function

  ## Returns

  - With `error_handling: true`: `{:ok, result} | {:error, Error.t()}`
  - With `error_handling: false`: Returns raw result or raises

  ## Examples

      config = %WrapperConfig{error_handling: true, ...}
      execute(config, :get_user, [123])
      #=> {:ok, %User{id: 123, name: "John"}}

      config = %WrapperConfig{error_handling: false, ...}
      execute(config, :get_user, [123])
      #=> %User{id: 123, name: "John"}
  """
  @impl true
  @spec execute(WrapperConfig.t(), function_name(), args()) :: result() | raw_result()
  def execute(%WrapperConfig{} = config, function, args)
      when is_atom(function) and is_list(args) do
    if config.error_handling or config.retry > 0 do
      execute_with_error_handling(config, function, args)
    else
      execute_without_error_handling(config, function, args)
    end
  end

  @doc """
  Executes an RPC call with automatic retry logic.

  This function always uses error handling and will retry on failure
  based on the retry count in the configuration.

  ## Parameters

  - `config` - WrapperConfig struct with retry count
  - `function` - Remote function name to call
  - `args` - List of arguments for the function

  ## Returns

  Always returns `{:ok, result} | {:error, Error.t()}`

  ## Examples

      config = %WrapperConfig{retry: 3, ...}
      execute_with_retry(config, :get_user, [123])
      #=> {:ok, %User{id: 123}}

      # After all retries exhausted
      execute_with_retry(config, :unreachable_fn, [])
      #=> {:error, %EasyRpc.Error{type: :rpc_error, message: "Max retries exhausted"}}
  """
  @impl true
  @spec execute_with_retry(WrapperConfig.t(), function_name(), args()) :: result()
  def execute_with_retry(%WrapperConfig{} = config, function, args) do
    config = %{config | error_handling: true}
    execute_with_error_handling(config, function, args)
  end

  @doc """
  Executes an RPC call with dynamically loaded configuration.

  This is useful when node configuration needs to be loaded at runtime
  rather than compile time. The node selector will be reloaded from
  the application configuration on each call.

  ## Parameters

  - `config` - WrapperConfig with static settings (timeout, retry, etc.)
  - `config_ref` - Tuple of `{app_name, config_name}` for loading node config
  - `function` - Remote function name to call
  - `args` - List of arguments for the function

  ## Returns

  - With `error_handling: true`: `{:ok, result} | {:error, Error.t()}`
  - With `error_handling: false`: Returns raw result or raises

  ## Examples

      config = %WrapperConfig{timeout: 5_000, retry: 2, ...}
      execute_dynamic(config, {:my_app, :remote_nodes}, :get_data, ["key"])
      #=> {:ok, "value"}
  """
  @spec execute_dynamic(WrapperConfig.t(), config_ref(), function_name(), args()) ::
          result() | raw_result()
  def execute_dynamic(%WrapperConfig{} = config, {app, config_name}, function, args)
      when is_atom(app) and is_atom(config_name) and is_atom(function) and is_list(args) do
    node_selector = NodeSelector.load_config!(app, config_name)
    config = %{config | node_selector: node_selector}

    execute(config, function, args)
  end

  @doc """
  Legacy wrapper for backward compatibility.
  Delegates to `execute/3`.
  """
  @spec rpc_call(WrapperConfig.t(), {function_name(), args()}) :: result() | raw_result()
  def rpc_call(%WrapperConfig{} = config, {function, args}) do
    execute(config, function, args)
  end

  @doc """
  Legacy wrapper for backward compatibility.
  Delegates to `execute_dynamic/4`.
  """
  @spec rpc_call_dynamic(WrapperConfig.t(), config_ref(), {function_name(), args()}) ::
          result() | raw_result()
  def rpc_call_dynamic(%WrapperConfig{} = config, config_ref, {function, args}) do
    execute_dynamic(config, config_ref, function, args)
  end

  ## Private Implementation

  # Executes RPC without catching exceptions
  defp execute_without_error_handling(config, function, args) do
    node = select_node(config, args)

    log_call(node, config.module, function, args, :debug)

    result = Erpc.call(node, config.module, function, args, config.timeout)

    log_result(node, config.module, function, args, result, :debug)

    result
  end

  # Executes RPC with full error handling and retry logic
  defp execute_with_error_handling(config, function, args, attempt \\ 0) do
    node = select_node(config, args)

    log_call(node, config.module, function, args, :debug, attempt)

    try do
      result = Erpc.call(node, config.module, function, args, config.timeout)

      log_result(node, config.module, function, args, result, :debug)

      {:ok, result}
    rescue
      exception ->
        handle_exception(config, function, args, node, exception, attempt)
    catch
      kind, reason ->
        handle_catch(config, function, args, node, kind, reason, attempt)
    end
  end

  # Handles rescued exceptions with retry logic
  defp handle_exception(config, function, args, node, exception, attempt) do
    error = Error.wrap_exception(exception, node: node, attempt: attempt)

    if should_retry?(config, attempt) do
      log_retry(node, config.module, function, args, config.retry - attempt, error)
      execute_with_error_handling(config, function, args, attempt + 1)
    else
      log_error(node, config.module, function, args, error)
      {:error, error}
    end
  end

  # Handles caught throws/exits with retry logic
  defp handle_catch(config, function, args, node, kind, reason, attempt) do
    error =
      Error.rpc_error("Caught #{kind}: #{inspect(reason)}",
        node: node,
        kind: kind,
        reason: reason,
        attempt: attempt
      )

    if should_retry?(config, attempt) do
      log_retry(node, config.module, function, args, config.retry - attempt, error)
      execute_with_error_handling(config, function, args, attempt + 1)
    else
      log_error(node, config.module, function, args, error)
      {:error, error}
    end
  end

  # Determines if retry should be attempted
  defp should_retry?(config, attempt) do
    config.retry > 0 and attempt < config.retry
  end

  # Selects target node using the configured strategy
  defp select_node(%WrapperConfig{node_selector: selector}, args) do
    NodeSelector.select_node(selector, args)
  end

  ## Logging Helpers

  defp log_call(node, module, function, args, level, attempt \\ 0) do
    arity = length(args)
    attempt_info = if attempt > 0, do: " [attempt: #{attempt + 1}]", else: ""

    Logger.log(
      level,
      "[EasyRpc.RpcCall] Calling #{inspect(module)}.#{function}/#{arity} on #{inspect(node)}#{attempt_info}"
    )
  end

  defp log_result(node, module, function, args, result, level) do
    arity = length(args)

    Logger.log(
      level,
      "[EasyRpc.RpcCall] Success #{inspect(module)}.#{function}/#{arity} on #{inspect(node)} => #{inspect(result)}"
    )
  end

  defp log_retry(node, module, function, args, retries_left, error) do
    arity = length(args)

    Logger.warning(
      "[EasyRpc.RpcCall] Retry #{inspect(module)}.#{function}/#{arity} on #{inspect(node)} " <>
        "(#{retries_left} retries left) | Error: #{Error.format(error)}"
    )
  end

  defp log_error(node, module, function, args, error) do
    arity = length(args)

    Logger.error(
      "[EasyRpc.RpcCall] Failed #{inspect(module)}.#{function}/#{arity} on #{inspect(node)} | " <>
        Error.format(error)
    )
  end
end
