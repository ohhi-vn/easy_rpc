defmodule EasyRpc.ConfigError do
  @moduledoc """
  Configuration error for EasyRpc.

  This module is kept for backward compatibility and delegates to `EasyRpc.Error`.

  ## Examples

      iex> EasyRpc.ConfigError.raise_error("Invalid timeout")
      ** (EasyRpc.Error) [EasyRpc.Error:config_error] Invalid timeout

  """

  alias EasyRpc.Error

  require Logger

  @doc """
  Raises a configuration error.

  ## Examples

      EasyRpc.ConfigError.raise_error("Invalid timeout value")
      EasyRpc.ConfigError.raise_error({:error, :invalid_config})
  """
  @spec raise_error(String.t() | term()) :: no_return()
  def raise_error(message) when is_binary(message) do
    Error.raise!(:config_error, message)
  end

  def raise_error(term) do
    Error.raise!(:config_error, inspect(term))
  end

  @doc """
  Prints the error to stdout.

  ## Examples

      error = EasyRpc.Error.config_error("Invalid config")
      EasyRpc.ConfigError.print(error)
  """
  @spec print(Error.t()) :: :ok
  def print(%Error{type: :config_error} = error) do
    IO.puts(Error.format(error))
  end

  def print(error) do
    IO.puts("EasyRpc.ConfigError: #{inspect(error)}")
  end

  @doc """
  Logs the error using Logger.

  ## Examples

      error = EasyRpc.Error.config_error("Invalid config")
      EasyRpc.ConfigError.log_error(error)
  """
  @spec log_error(Error.t() | term()) :: :ok
  def log_error(%Error{type: :config_error} = error) do
    Error.log(error, :error)
  end

  def log_error(error) do
    Logger.error("EasyRpc.ConfigError: #{inspect(error)}")
  end
end
