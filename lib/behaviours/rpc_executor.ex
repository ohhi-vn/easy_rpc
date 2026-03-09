defmodule EasyRpc.Behaviours.RpcExecutor do
  @moduledoc """
  Behaviour for RPC execution implementations.

  Defines the contract for executing remote procedure calls in the EasyRpc
  library. Implementations must handle node selection, error handling,
  retries, and timeouts.

  ## Callbacks

  - `execute/3` - Execute an RPC call with the given configuration
  - `execute_with_retry/3` - Execute with automatic retry logic
  - `validate_config/1` - Optional config pre-validation hook
  """

  alias EasyRpc.WrapperConfig

  @type function_name :: atom()
  @type args :: list()
  @type result :: {:ok, term()} | {:error, term()}
  @type raw_result :: term()

  @doc """
  Executes an RPC call without automatic retry.

  Returns `{:ok, result} | {:error, EasyRpc.Error.t()}` when
  `error_handling: true`, or the raw result (raising on error) otherwise.
  """
  @callback execute(
              config :: WrapperConfig.t(),
              function :: function_name(),
              args :: args()
            ) :: result() | raw_result()

  @doc """
  Executes an RPC call with automatic retry logic.

  Always returns `{:ok, result} | {:error, EasyRpc.Error.t()}`.
  """
  @callback execute_with_retry(
              config :: WrapperConfig.t(),
              function :: function_name(),
              args :: args()
            ) :: result()

  @doc """
  Optional callback for validating configuration before execution.

  Returns `:ok` or `{:error, reason}`.
  """
  @callback validate_config(config :: WrapperConfig.t()) :: :ok | {:error, term()}

  @optional_callbacks validate_config: 1
end
