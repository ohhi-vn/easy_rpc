defmodule EasyRpc.ConfigError do
  @moduledoc """
  Kept for backward compatibility. Delegates to `EasyRpc.Error`.

  New code should use `EasyRpc.Error` directly.
  """

  alias EasyRpc.Error
  require Logger

  @doc "Raises a `:config_error`. Prefer `EasyRpc.Error.raise!/2`."
  @spec raise_error(String.t() | term()) :: no_return()
  def raise_error(message) when is_binary(message), do: Error.raise!(:config_error, message)
  def raise_error(term), do: Error.raise!(:config_error, inspect(term))

  @doc "Prints a config error to stdout."
  @spec print(Error.t() | term()) :: :ok
  def print(%Error{type: :config_error} = error), do: IO.puts(Error.format(error))
  def print(error), do: IO.puts("EasyRpc.ConfigError: #{inspect(error)}")

  @doc "Logs a config error via Logger."
  @spec log_error(Error.t() | term()) :: :ok
  def log_error(%Error{type: :config_error} = error), do: Error.log(error, :error)
  def log_error(error), do: Logger.error("EasyRpc.ConfigError: #{inspect(error)}")
end
