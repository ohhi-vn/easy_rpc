defmodule EasyRpc.Utils.RpcCall do
  @moduledoc false

  alias :erpc, as: Rpc

  import EasyRpc.Utils.RpcUtils

  require Logger

  @spec rpc_call(
          {false | true, non_neg_integer()},
          {atom(), atom(), list()},
          {[atom()] | {atom(), atom(), list()}, atom, non_neg_integer() | :infinity}
        ) :: any()
  @doc false
  def rpc_call({error_handling, retry},  {mod, fun, args}, {nodes, strategy, timeout}) do
    case error_handling do
      true ->
        rpc_call_error_handling({nodes, mod, fun}, args, strategy, retry, timeout)
      false ->
        rpc_call_no_error_handling({nodes, mod, fun}, args, strategy, timeout)
    end
  end

  @spec rpc_call_dynamic(
          {false | true, non_neg_integer(), non_neg_integer() | :infinity},
          {atom(), atom()},
          {atom(), atom(), list()}
        ) :: any()
  @doc false
  def rpc_call_dynamic({error_handling, retry, timeout}, {config_app, config_name}, {mod, fun, args}) do
    nodes = get_config!(config_app, config_name, :nodes)
    strategy = get_config!(config_app, config_name, :select_mode)

    case error_handling do
      true ->
        rpc_call_error_handling({nodes, mod, fun}, args, strategy, retry, timeout)
      false ->
        rpc_call_no_error_handling({nodes, mod, fun}, args, strategy, timeout)
    end
  end

  defp rpc_call_no_error_handling({nodes, mod, fun}, args, strategy, timeout) do
    node = EasyRpc.NodeUtils.select_node(nodes, strategy, {mod, args})

    prefix_log = "easy_rpc, rpcwrapper, rpc_call, node: #{inspect node}, #{inspect mod}/#{inspect fun}/#{length(args)}, args: #{inspect args}"

    Logger.debug(prefix_log <> ", calling")

    Rpc.call(node, mod, fun, args, timeout)
  end

  defp rpc_call_error_handling({nodes, mod, fun}, args, strategy, retry, timeout) do
    node = select_node(nodes, {strategy, mod, args})

    prefix_log = "easy_rpc, rpcwrapper, rpc_call, node: #{inspect node}, #{inspect mod}/#{inspect fun}/#{length(args)}, args: #{inspect args}"

    try do
      Logger.debug(prefix_log <> ", call")

      case Rpc.call(node, mod, fun, args, timeout) do
        {:error, reason} ->
          Logger.error(prefix_log <> ", error: #{inspect(reason)}")
          false
        result ->
          Logger.info(prefix_log <> ", result: #{inspect result}")
          {:ok, result}
      end
    rescue
      e ->
        if retry > 0 do
          Logger.error(prefix_log <> ", retry: #{inspect(retry)} (decrease), error: #{inspect(e)}")
          rpc_call_error_handling({nodes, mod, fun}, args, strategy, retry - 1, timeout)
        else
          Logger.error(prefix_log <> ", error: #{inspect(e)}")
          {:error, e}
        end
    catch
      e ->
        Logger.error(prefix_log <> ", catched unknown throw exception, #{inspect(e)}")
        {:error, e}
    end
  end
end
