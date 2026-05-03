defmodule EasyRpc.Verifiers.ValidateConfig do
  @moduledoc """
  Verifies that the EasyRpc DSL configuration is valid.

  Checks:
  - Required fields are present (nodes, module)
  - Node list is not empty
  - Timeout and retry values are valid
  - All rpc_functions reference valid arities
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier
  alias EasyRpc.Error

  def verify(dsl_state) do
    # Verify config section
    case verify_config(dsl_state) do
      :ok ->
        # Verify rpc_functions
        verify_functions(dsl_state)

      {:error, %EasyRpc.Error{} = error} ->
        raise error
    end
  end

  defp verify_config(dsl_state) do
    nodes = Verifier.get_option(dsl_state, [:config], :nodes)
    nodes_provider = Verifier.get_option(dsl_state, [:config], :nodes_provider)
    module = Verifier.get_option(dsl_state, [:config], :module)
    timeout = Verifier.get_option(dsl_state, [:config], :timeout)
    retry = Verifier.get_option(dsl_state, [:config], :retry)

    with :ok <- validate_nodes_or_provider(nodes, nodes_provider),
         :ok <- validate_module(module),
         :ok <- validate_timeout(timeout),
         :ok <- validate_retry(retry) do
      :ok
    end
  end

  defp validate_nodes_or_provider(nodes, nodes_provider) do
    cond do
      nodes != nil and nodes_provider != nil ->
        raise Error.exception(
          message: "Cannot specify both :nodes and :nodes_provider — use one or the other"
        )

      nodes != nil ->
        validate_nodes(nodes)

      nodes_provider != nil ->
        validate_nodes_provider(nodes_provider)

      true ->
        raise Error.exception(
          message: "Either :nodes or :nodes_provider must be specified"
        )
    end
  end

  defp validate_nodes(nodes) when is_list(nodes) and length(nodes) > 0 do
    unless Enum.all?(nodes, &is_atom/1) do
      raise Error.exception(
        message: "All nodes must be atoms, got: #{inspect(nodes)}"
      )
    else
      :ok
    end
  end

  defp validate_nodes(_nodes) do
    raise Error.exception(
      message: "Config :nodes must be a non-empty list of node names"
    )
  end

  defp validate_nodes_provider({mod, fun, args})
       when is_atom(mod) and is_atom(fun) and is_list(args) do
    :ok
  end

  defp validate_nodes_provider(_) do
    raise Error.exception(
      message: "Config :nodes_provider must be {module, function, args}"
    )
  end

  defp validate_module(module) when is_atom(module) and not is_nil(module) do
    :ok
  end

  defp validate_module(_module) do
    raise Error.exception(
      message: "Config :module must be a valid module atom"
    )
  end

  defp validate_timeout(:infinity), do: :ok

  defp validate_timeout(timeout) when is_integer(timeout) and timeout > 0 do
    :ok
  end

  defp validate_timeout(_timeout) do
    raise Error.exception(
      message: "Config :timeout must be a positive integer or :infinity"
    )
  end

  defp validate_retry(retry) when is_integer(retry) and retry >= 0 do
    :ok
  end

  defp validate_retry(_retry) do
    raise Error.exception(
      message: "Config :retry must be a non-negative integer"
    )
  end

  defp verify_functions(dsl_state) do
    functions = Verifier.get_entities(dsl_state, [:rpc_functions])

    Enum.reduce_while(functions, :ok, fn fun, _acc ->
      case validate_function(fun) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_function(fun) do
    with :ok <- validate_function_name(fun.name),
         :ok <- validate_function_arity(fun.arity) do
      :ok
    end
  end

  defp validate_function_name(name) when is_atom(name) do
    :ok
  end

  defp validate_function_name(_name) do
    raise Error.exception(
      message: "Function name must be an atom"
    )
  end

  defp validate_function_arity(arity) when is_integer(arity) and arity >= 0 do
    :ok
  end

  defp validate_function_arity(arity) when is_list(arity) do
    if Enum.all?(arity, &is_atom/1) do
      :ok
    else
      raise Error.exception(
        message: "Function arity as list must contain only atoms"
      )
    end
  end

  defp validate_function_arity(_arity) do
    raise Error.exception(
      message: "Function arity must be a non-negative integer or a list of atoms"
    )
  end
end
