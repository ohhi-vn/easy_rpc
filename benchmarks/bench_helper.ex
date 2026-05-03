defmodule BenchHelper do
  @moduledoc """
  Helper module for benchmarks.
  Provides utilities to measure compilation time, memory usage, and runtime performance.
  """

  @doc """
  Measures the time to compile a module defined by the given quoted expression.

  Returns `{time_in_microseconds, result}`.
  """
  def measure_compile_time(quoted) do
    {time, result} = :timer.tc(fn ->
      Code.compile_quoted(quoted)
    end)
    {time, result}
  end

  @doc """
  Measures the memory before and after compiling a module.

  Returns `{memory_before, memory_after, result}`.
  """
  def measure_memory(quoted) do
    :erlang.garbage_collect()
    mem_before = :erlang.memory(:total)

    result = Code.compile_quoted(quoted)

    :erlang.garbage_collect()
    mem_after = :erlang.memory(:total)

    {mem_before, mem_after, result}
  end

  @doc """
  Creates a Spark DSL module quote for benchmarking.
  """
  def spark_dsl_module_quote(module_name, functions) do
    function_defs = Enum.map(functions, fn {name, arity} ->
      quote do
        rpc_function unquote(name), unquote(arity)
      end
    end)

    quote do
      defmodule unquote(module_name) do
        use EasyRpc

        config do
          nodes [:"node1@host", :"node2@host"]
          select_mode :round_robin
          module RemoteNode.Api
          timeout 5_000
          retry 0
          error_handling false
        end

        rpc_functions do
          unquote_splicing(function_defs)
        end
      end
    end
  end

  @doc """
  Creates a DefRpc macro module quote for benchmarking.
  """
  def defrpc_module_quote(module_name, functions) do
    function_defs = Enum.map(functions, fn {name, arity} ->
      quote do
        defrpc unquote(name), args: unquote(arity)
      end
    end)

    quote do
      defmodule unquote(module_name) do
        use EasyRpc.DefRpc,
          otp_app: :my_app,
          config_name: :bench_config,
          module: RemoteNode.Api,
          timeout: 5_000

        unquote_splicing(function_defs)
      end
    end
  end

  @doc """
  Creates an RpcWrapper macro module quote for benchmarking.
  """
  def rpc_wrapper_module_quote(module_name, functions) do
    _function_list = Enum.map(functions, fn {name, arity} ->
      {name, arity}
    end)

    quote do
      defmodule unquote(module_name) do
        use EasyRpc.RpcWrapper,
          otp_app: :my_app,
          config_name: :bench_wrapper_config
      end
    end
  end

  @doc """
  Formats microseconds into a readable string.
  """
  def format_time(us) when us < 1000, do: "#{us} µs"
  def format_time(us) when us < 1_000_000, do: "#{Float.round(us / 1000, 2)} ms"
  def format_time(us), do: "#{Float.round(us / 1_000_000, 2)} s"

  @doc """
  Formats bytes into a readable string.
  """
  def format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  def format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 2)} KB"
  def format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 2)} MB"
end
