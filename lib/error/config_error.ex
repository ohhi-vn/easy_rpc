defmodule EasyRpc.ConfigError do
  defexception [:message]

  alias __MODULE__

  require Logger

  def raise_error(error) when is_binary(error) do
    raise ConfigError, message: error
  end

  def raise_error(error) do
    raise ConfigError, message: "#{inspect(error)}"
  end

  def print(%ConfigError{} = error) do
    IO.puts("EasyRpc.ConfigError: #{error.message}")
  end

  def log_error(%ConfigError{} = error) do
    Logger.error("EasyRpc.ConfigError: #{error.message}")
  end
end
