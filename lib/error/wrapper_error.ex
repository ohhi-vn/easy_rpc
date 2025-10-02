defmodule EasyRpc.RpcError do
  @moduledoc """
  RPC error for EasyRpc.

  This module is kept for backward compatibility and delegates to `EasyRpc.Error`.

  ## Examples

      iex> EasyRpc.RpcError.raise_error("Connection failed")
      ** (EasyRpc.Error) [EasyRpc.Error:rpc_error] Connection failed

  """

  alias EasyRpc.Error

  require Logger

  @doc """
  Raises an RPC error.

  ## Examples

      EasyRpc.RpcError.raise_error("Connection refused")
      EasyRpc.RpcError.raise_error({:error, :nodedown})
  """
  @spec raise_error(String.t() | term()) :: no_return()
  def raise_error(message) when is_binary(message) do
    Error.raise!(:rpc_error, message)
  end

  def raise_error(term) do
    Error.raise!(:rpc_error, inspect(term))
  end

  @doc """
  Prints the error to stdout.

  ## Examples

      error = EasyRpc.Error.rpc_error("Connection failed")
      EasyRpc.RpcError.print(error)
  """
  @spec print(Error.t()) :: :ok
  def print(%Error{type: :rpc_error} = error) do
    IO.puts(Error.format(error))
  end

  def print(error) do
    IO.puts("EasyRpc.RpcError: #{inspect(error)}")
  end

  @doc """
  Logs the error using Logger.

  ## Examples

      error = EasyRpc.Error.rpc_error("Connection failed")
      EasyRpc.RpcError.log_error(error)
  """
  @spec log_error(Error.t() | term()) :: :ok
  def log_error(%Error{type: :rpc_error} = error) do
    Error.log(error, :error)
  end

  def log_error(error) do
    Logger.error("EasyRpc.RpcError: #{inspect(error)}")
  end
end
