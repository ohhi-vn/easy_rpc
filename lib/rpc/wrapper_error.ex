defmodule EasyRpc.RpcWrapperError do
  defexception [:message]

  alias __MODULE__

  def raise_error(error) when is_binary(error) do
    raise RpcWrapperError, message: error
  end
end
