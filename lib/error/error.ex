defmodule EasyRpc.Error do
  @moduledoc """
  Unified error handling for EasyRpc library.

  Provides structured errors with typed categories, optional detail metadata,
  and helpers for creation, logging, formatting, and wrapping raw exceptions.

  ## Error Types

  - `:config_error`     - Configuration validation errors
  - `:rpc_error`        - Remote procedure call errors
  - `:node_error`       - Node selection or availability errors
  - `:timeout_error`    - RPC timeout errors
  - `:validation_error` - Input validation errors

  ## Examples

      iex> EasyRpc.Error.config_error("Invalid timeout value")
      %EasyRpc.Error{type: :config_error, message: "Invalid timeout value", details: nil}

      iex> EasyRpc.Error.rpc_error("Connection refused", node: :node1@host)
      %EasyRpc.Error{type: :rpc_error, message: "Connection refused", details: [node: :node1@host]}
  """

  @type error_type ::
          :config_error
          | :rpc_error
          | :node_error
          | :timeout_error
          | :validation_error

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          details: keyword() | map() | nil
        }

  defexception [:type, :message, :details]

  require Logger

  ## Constructors

  @doc "Creates a configuration error."
  @spec config_error(String.t() | term(), keyword()) :: t()
  def config_error(message, details \\ [])

  def config_error(message, details) when is_binary(message),
    do: %__MODULE__{type: :config_error, message: message, details: details}

  def config_error(term, details),
    do: %__MODULE__{type: :config_error, message: inspect(term), details: details}

  @doc "Creates an RPC error."
  @spec rpc_error(String.t() | term(), keyword()) :: t()
  def rpc_error(message, details \\ [])

  def rpc_error(message, details) when is_binary(message),
    do: %__MODULE__{type: :rpc_error, message: message, details: details}

  def rpc_error(term, details),
    do: %__MODULE__{type: :rpc_error, message: inspect(term), details: details}

  @doc "Creates a node error."
  @spec node_error(String.t() | term(), keyword()) :: t()
  def node_error(message, details \\ [])

  def node_error(message, details) when is_binary(message),
    do: %__MODULE__{type: :node_error, message: message, details: details}

  def node_error(term, details),
    do: %__MODULE__{type: :node_error, message: inspect(term), details: details}

  @doc "Creates a timeout error."
  @spec timeout_error(String.t() | term(), keyword()) :: t()
  def timeout_error(message, details \\ [])

  def timeout_error(message, details) when is_binary(message),
    do: %__MODULE__{type: :timeout_error, message: message, details: details}

  def timeout_error(term, details),
    do: %__MODULE__{type: :timeout_error, message: inspect(term), details: details}

  @doc "Creates a validation error."
  @spec validation_error(String.t() | term(), keyword()) :: t()
  def validation_error(message, details \\ [])

  def validation_error(message, details) when is_binary(message),
    do: %__MODULE__{type: :validation_error, message: message, details: details}

  def validation_error(term, details),
    do: %__MODULE__{type: :validation_error, message: inspect(term), details: details}

  ## Raise Helpers

  @doc """
  Raises an error by type + message, or directly from an existing `%EasyRpc.Error{}`.

  ## Examples

      EasyRpc.Error.raise!(:config_error, "Invalid config")
      EasyRpc.Error.raise!(error_struct)
  """
  @spec raise!(error_type(), String.t(), keyword()) :: no_return()
  def raise!(type, message, details \\ []) when is_atom(type) and is_binary(message) do
    raise %__MODULE__{type: type, message: message, details: details}
  end

  @spec raise!(t()) :: no_return()
  def raise!(%__MODULE__{} = error), do: raise(error)

  ## Logging

  @doc """
  Logs the error at the given level (default `:error`).
  """
  @spec log(t(), :error | :warning | :info | :debug) :: :ok
  def log(%__MODULE__{} = error, level \\ :error) do
    msg = format(error)

    case level do
      :error -> Logger.error(msg)
      :warning -> Logger.warning(msg)
      :info -> Logger.info(msg)
      :debug -> Logger.debug(msg)
    end
  end

  ## Formatting

  @doc """
  Formats the error as a human-readable string.

  ## Examples

      iex> EasyRpc.Error.format(EasyRpc.Error.config_error("Invalid timeout"))
      "[config_error] Invalid timeout"

      iex> EasyRpc.Error.format(EasyRpc.Error.rpc_error("Refused", node: :n1@h))
      "[rpc_error] Refused | details: [node: :n1@h]"
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{type: type, message: message, details: nil}),
    do: "[#{type}] #{message}"

  def format(%__MODULE__{type: type, message: message, details: []}),
    do: "[#{type}] #{message}"

  def format(%__MODULE__{type: type, message: message, details: details}),
    do: "[#{type}] #{message} | details: #{inspect(details)}"

  ## Exception Wrapping

  @doc """
  Wraps a rescued exception into an `EasyRpc.Error`, preserving the original
  struct name in `:details`.

  ## Examples

      try do
        :erpc.call(node, mod, fun, args)
      rescue
        e -> EasyRpc.Error.wrap_exception(e, node: node)
      end
  """
  @spec wrap_exception(Exception.t(), keyword()) :: t()
  def wrap_exception(exception, details \\ []) do
    %__MODULE__{
      type: classify_exception(exception),
      message: Exception.message(exception),
      details: Keyword.put(details, :exception, exception.__struct__)
    }
  end

  ## Exception.message/1 callback
  @impl true
  def message(%__MODULE__{} = error), do: format(error)

  ## Private

  defp classify_exception(%{__struct__: module}) do
    name = inspect(module) |> String.downcase()

    cond do
      String.contains?(name, "timeout") -> :timeout_error
      String.contains?(name, "noconnection") -> :node_error
      String.contains?(name, "nodedown") -> :node_error
      true -> :rpc_error
    end
  end

  defp classify_exception(_), do: :rpc_error
end
