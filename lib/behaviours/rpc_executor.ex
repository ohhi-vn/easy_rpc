defmodule EasyRpc.Behaviours.RpcExecutor do
  @moduledoc """
  Behavior for RPC execution implementations.

  This module defines the contract for executing remote procedure calls
  in the EasyRpc library. Implementations must handle node selection,
  error handling, retries, and timeouts.

  ## Callbacks

  - `execute/3` - Execute an RPC call with the given configuration
  - `execute_with_retry/3` - Execute an RPC call with retry logic

  ## Examples

  Implementing the behavior:

      defmodule MyRpcExecutor do
        @behaviour EasyRpc.Behaviours.RpcExecutor

        @impl true
        def execute(config, function, args) do
          # Implementation
        end

        @impl true
        def execute_with_retry(config, function, args) do
          # Implementation with retry logic
        end
      end
  """

  alias EasyRpc.WrapperConfig

  @type function_name :: atom()
  @type args :: list()
  @type result :: {:ok, term()} | {:error, term()}
  @type raw_result :: term()

  @doc """
  Executes an RPC call without automatic retry.

  ## Parameters

  - `config` - The wrapper configuration containing node selector, timeout, etc.
  - `function` - The function name to call on the remote node
  - `args` - List of arguments to pass to the function

  ## Returns

  - When `error_handling: true`: `{:ok, result} | {:error, reason}`
  - When `error_handling: false`: Returns the raw result or raises

  ## Examples

      execute(config, :get_data, ["key1"])
      #=> {:ok, %{data: "value"}}

      execute(config, :invalid_function, [])
      #=> {:error, %EasyRpc.Error{type: :rpc_error, ...}}
  """
  @callback execute(config :: WrapperConfig.t(), function :: function_name(), args :: args()) ::
              result() | raw_result()

  @doc """
  Executes an RPC call with automatic retry logic.

  This function will retry the RPC call based on the retry configuration
  in the WrapperConfig. It automatically handles errors and retries on failure.

  ## Parameters

  - `config` - The wrapper configuration with retry count
  - `function` - The function name to call on the remote node
  - `args` - List of arguments to pass to the function

  ## Returns

  Always returns `{:ok, result} | {:error, reason}` tuple

  ## Examples

      config = %WrapperConfig{retry: 3, ...}
      execute_with_retry(config, :get_data, ["key1"])
      #=> {:ok, %{data: "value"}}

      # On failure after retries
      execute_with_retry(config, :unreachable_function, [])
      #=> {:error, %EasyRpc.Error{type: :rpc_error, message: "Max retries exceeded"}}
  """
  @callback execute_with_retry(
              config :: WrapperConfig.t(),
              function :: function_name(),
              args :: args()
            ) :: result()

  @doc """
  Optional callback for validating configuration before execution.

  Implementations can use this to perform additional validation
  beyond the standard WrapperConfig validation.

  ## Parameters

  - `config` - The wrapper configuration to validate

  ## Returns

  - `:ok` if valid
  - `{:error, reason}` if invalid
  """
  @callback validate_config(config :: WrapperConfig.t()) ::
              :ok | {:error, term()}

  @optional_callbacks validate_config: 1
end
