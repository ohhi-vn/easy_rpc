defmodule EasyRpc.RpcCall do
  @moduledoc false

  alias :erpc, as: Rpc

  alias EasyRpc.{WrapperConfig, NodeSelector}

  require Logger

  @doc false
  def rpc_call(%WrapperConfig{} = config, fun_args) do
    case config.error_handling do
      true ->
        rpc_call_error_handling(config, fun_args)
      false ->
        rpc_call_no_error_handling(config, fun_args)
    end
  end

  @doc false
  def rpc_call_dynamic(%WrapperConfig{} = config, {config_app, config_name}, {_, _} = fun_args) do
    node_selector = NodeSelector.load_config!(config_app, config_name)

    config = %WrapperConfig{config | node_selector: node_selector}

    case config.error_handling do
      true ->
        rpc_call_error_handling(config, fun_args)
      false ->
        rpc_call_no_error_handling(config, fun_args)
    end
  end

  ## Private functions ##

  defp rpc_call_no_error_handling(config = %WrapperConfig{}, {fun, args}) do
    node = NodeSelector.select_node(config.node_selector, {config.module, args})

    Logger.debug("easy_rpc, rpcwrapper, rpc_call, node: #{inspect node}, #{inspect config.module}.#{inspect fun}/#{length(args)}")
    Rpc.call(node, config.module, fun, args, config.timeout)
  end

  defp rpc_call_error_handling(config = %WrapperConfig{}, {fun, args} = fun_args) do
    node = NodeSelector.select_node(config.node_selector, {config.module, args})

    prefix_log = "easy_rpc, rpcwrapper, rpc_call, node: #{inspect node}, #{inspect config.module}.#{inspect fun}/#{length(args)}"

    try do
      Logger.debug(prefix_log <> ", call")

      case Rpc.call(node, config.module, fun, args, config.timeout) do
        {:error, reason} ->
          Logger.error(prefix_log <> ", error: #{inspect(reason)}")
          false
        result ->
          Logger.info(prefix_log <> ", result: #{inspect result}")
          {:ok, result}
      end
    rescue
      e ->
        if config.retry > 0 do
          Logger.warning(prefix_log <> ", retry: #{inspect(config.retry)} (decrease), error: #{inspect(e)}")
          config = %WrapperConfig{config | retry: config.retry - 1}
          rpc_call_error_handling(config, fun_args)
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
