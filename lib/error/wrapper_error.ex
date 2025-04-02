defmodule EasyRpc.RpcError do
  defexception [:message]

  alias __MODULE__

  require Logger

  def raise_error(error) when is_binary(error) do
    raise RpcError, message: error
  end

  def raise_error(error) do
    raise RpcError, message: "#{inspect(error)}"
  end

  def print(EasyRpc.RpcError) do
    IO.puts("EasyRpc.RpcError")
  end

  def log_error(error) do
    Logger.error("EasyRpc.RpcError: #{inspect(error)}")
  end
end
