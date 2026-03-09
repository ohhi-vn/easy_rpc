defmodule EasyRpc.RpcCall do
  @moduledoc """
  Core module for executing remote procedure calls.

  Handles RPC execution with:
  - Configurable error handling (tuple vs. raise)
  - Automatic retries with per-attempt logging
  - Node selection via `NodeSelector`
  - Timeout management via `:erpc`
  - Detailed structured logging at every stage

  Implements `EasyRpc.Behaviours.RpcExecutor`.

  ## Examples

      config = WrapperConfig.new!(node_selector, RemoteModule, 5_000, 3, true)

      {:ok, result}    = EasyRpc.RpcCall.execute(config, :get_data, ["key"])
      {:error, reason} = EasyRpc.RpcCall.execute(config, :missing_fn, [])
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
  Executes an RPC call using the given `WrapperConfig`.

  Delegates to error-handling or bare execution based on
  `config.error_handling` and `config.retry`.

  Returns `{:ok, result} | {:error, Error.t()}` with error handling,
  or the raw result (raising on failure) without.
  """
  @impl true
  @spec execute(WrapperConfig.t(), function_name(), args()) :: result() | raw_result()
  def execute(%WrapperConfig{} = config, function, args)
      when is_atom(function) and is_list(args) do
    if config.error_handling or config.retry > 0 do
      execute_with_error_handling(config, function, args)
    else
      execute_bare(config, function, args)
    end
  end

  @doc """
  Executes an RPC call with automatic retry. Always uses error handling.

  Returns `{:ok, result} | {:error, Error.t()}`.
  """
  @impl true
  @spec execute_with_retry(WrapperConfig.t(), function_name(), args()) :: result()
  def execute_with_retry(%WrapperConfig{} = config, function, args) do
    execute_with_error_handling(%{config | error_handling: true}, function, args)
  end

  @doc """
  Executes with a dynamically resolved `NodeSelector`.

  Loads the node selector at call-time from `{app, config_name}` rather than
  compile-time. Useful when cluster topology changes at runtime.
  """
  @spec execute_dynamic(WrapperConfig.t(), config_ref(), function_name(), args()) ::
          result() | raw_result()
  def execute_dynamic(%WrapperConfig{} = config, {app, config_name}, function, args)
      when is_atom(app) and is_atom(config_name) and is_atom(function) and is_list(args) do
    node_selector = NodeSelector.load_config!(app, config_name)
    execute(%{config | node_selector: node_selector}, function, args)
  end

  @doc "Backward-compatible alias for `execute/3`."
  @spec rpc_call(WrapperConfig.t(), {function_name(), args()}) :: result() | raw_result()
  def rpc_call(%WrapperConfig{} = config, {function, args}),
    do: execute(config, function, args)

  @doc "Backward-compatible alias for `execute_dynamic/4`."
  @spec rpc_call_dynamic(WrapperConfig.t(), config_ref(), {function_name(), args()}) ::
          result() | raw_result()
  def rpc_call_dynamic(%WrapperConfig{} = config, config_ref, {function, args}),
    do: execute_dynamic(config, config_ref, function, args)

  ## Private — Execution

  # Bare execution: no rescue, raises on any error.
  defp execute_bare(config, function, args) do
    node = select_node(config, args)
    log_call(config, node, function, args, :debug)
    result = Erpc.call(node, config.module, function, args, config.timeout)
    log_success(config, node, function, args, result, :debug)
    result
  end

  # Full execution: rescues exceptions, supports retry.
  defp execute_with_error_handling(config, function, args, attempt \\ 0) do
    node = select_node(config, args)
    log_call(config, node, function, args, :debug, attempt)

    try do
      result = Erpc.call(node, config.module, function, args, config.timeout)
      log_success(config, node, function, args, result, :debug)
      {:ok, result}
    rescue
      exception ->
        error =
          Error.wrap_exception(exception,
            node: node,
            attempt: attempt,
            module: config.module,
            function: function
          )

        handle_error(config, function, args, node, error, attempt)
    catch
      kind, reason ->
        error =
          Error.rpc_error(
            "Caught #{kind}: #{inspect(reason)}",
            node: node,
            kind: kind,
            reason: reason,
            attempt: attempt,
            module: config.module,
            function: function
          )

        handle_error(config, function, args, node, error, attempt)
    end
  end

  defp handle_error(config, function, args, node, error, attempt) do
    if should_retry?(config, attempt) do
      retries_left = config.retry - attempt
      log_retry(config, node, function, args, retries_left, attempt, error)
      execute_with_error_handling(config, function, args, attempt + 1)
    else
      log_failure(config, node, function, args, attempt, error)
      {:error, error}
    end
  end

  defp should_retry?(config, attempt), do: config.retry > 0 and attempt < config.retry

  defp select_node(%WrapperConfig{node_selector: selector}, args),
    do: NodeSelector.select_node(selector, args)

  ## Private — Logging

  defp timeout_str(:infinity), do: "∞"
  defp timeout_str(ms), do: "#{ms}ms"

  defp attempt_str(0), do: ""
  defp attempt_str(n), do: " [attempt #{n + 1}]"

  defp rpc_label(config, function, args),
    do: "#{inspect(config.module)}.#{function}/#{length(args)}"

  defp log_call(config, node, function, args, level, attempt \\ 0) do
    Logger.log(
      level,
      "[EasyRpc] --> #{rpc_label(config, function, args)} on #{inspect(node)}" <>
        attempt_str(attempt) <>
        " [timeout: #{timeout_str(config.timeout)}, retry: #{config.retry}]"
    )
  end

  defp log_success(config, node, function, args, result, level) do
    Logger.log(
      level,
      "[EasyRpc] <-- #{rpc_label(config, function, args)} on #{inspect(node)} " <>
        "succeeded — result: #{inspect(result)}"
    )
  end

  defp log_retry(config, node, function, args, retries_left, attempt, error) do
    Logger.warning(
      "[EasyRpc] <<< #{rpc_label(config, function, args)} on #{inspect(node)} failed " <>
        "(attempt #{attempt + 1}/#{config.retry + 1}, #{retries_left} retries left) — " <>
        Error.format(error)
    )
  end

  defp log_failure(config, node, function, args, attempt, error) do
    total_attempts = attempt + 1

    Logger.error(
      "[EasyRpc] !!! #{rpc_label(config, function, args)} on #{inspect(node)} " <>
        "failed permanently after #{total_attempts} attempt(s) — #{Error.format(error)}"
    )
  end
end
