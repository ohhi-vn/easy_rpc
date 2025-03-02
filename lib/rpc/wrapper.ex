defmodule EasyRpc.RpcWrapper do
  @moduledoc """
  This module provides a wrapper for RPC (Remote Procedure Call) functionalities.
  It includes functions to facilitate communication between different parts of the system
  or between different systems over a network.

  ## Configuration for RpcWrapper
  Put config to config.exs file, and use it in your module by using RpcWrapper.
  User need separate config for each wrapper, and put it in config.exs

  `:nodes` List of nodes, or {module, function, args} to get nodes.
  `:module` Module of remote functions on remote node.
  `:error_handling` Enable error handling (catch all) or not.
  `:select_node_mode` Select node mode, support for random, round_robin, hash.
  `:functions` list of functions, each function is a tuple {function_name, arity} or {function_name, new_name, arity, opts}.
  `:opts` Map of options, including new_name, retry, error_handling. Ex: [new_name: :clear_data, retry: 3, error_handling: false]

  ```Elixir
  config :app_name, :wrapper_name,
    nodes: [:"test1@test.local"],
    # or nodes: {MyModule, :get_nodes, []}
    error_handling: true, # enable error handling, global setting for all functions.
    select_node_mode: :random, # select node mode, global setting for all functions.
    module: TargetApp.RemoteModule,
    functions: [
      # {function_name, arity}
      {:get_data, 1},
      {:put_data, 1},
      # {function_name, arity, opts}
      {:clear, 2, [new_name: :clear_data, retry: 3, error_handling: false]},
    ]
  ```

  usage:
  by using RpcWrapper in your module, you can call remote functions as local functions.

  :otp_app, name of application will add config
  :config_name, name of config in application

  ```Elixir
  defmodule DataHelper do
  use EasyRpc.RpcWrapper,
    otp_app: :app_name,
    config_name: :account_wrapper

  def process_remote() do
    case get_data("key") do
      {:ok, data} ->
        # do something with data
      {:error, reason} ->
        # handle error
    end
  end
  ```
  """

  alias :erpc, as: Rpc

  alias __MODULE__

  require Logger

  defmodule RpcWrapperError do
    defexception [:message]

    def raise_error(error) when is_binary(error) do
      raise RpcWrapperError, message: error
    end
  end

  defmacro __using__(opts) do
    # using location for debug & dev, remove for production
    quote location: :keep, bind_quoted: [opts: opts] do
      rpc_wrapper_app_name = Keyword.get(opts, :otp_app)
      rpc_wrapper_config_name = Keyword.get(opts, :config_name)
      rpc_error_handling = Keyword.get(opts, :error_handling, false)

      rpc_wrapper_nodes = quote do RpcWrapper.get_config!(unquote(rpc_wrapper_app_name), unquote(rpc_wrapper_config_name), :nodes) end
      rpc_wrapper_module = quote do RpcWrapper.get_config!(unquote(rpc_wrapper_app_name), unquote(rpc_wrapper_config_name), :module) end
      rpc_wrapper_functions = RpcWrapper.get_config!(rpc_wrapper_app_name, rpc_wrapper_config_name, :functions)

      for fun_info <- rpc_wrapper_functions do
        case fun_info do
          {fun, arity} ->
            if rpc_error_handling do
              def unquote(fun)(unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ) do
                RpcWrapper.rpc_call_error_handling({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module), unquote(fun)}, [unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ])
              end
            else
              def unquote(fun)(unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ) do
                RpcWrapper.rpc_call({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module), unquote(fun)}, [unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ])
              end
            end
          {fun, new_name, arity} ->
            if rpc_error_handling do
              def unquote(new_name)(unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ) do
                RpcWrapper.rpc_call_error_handling({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module), unquote(fun)}, [unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ])
              end
            else
              def unquote(new_name)(unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ) do
                RpcWrapper.rpc_call({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module), unquote(fun)}, [unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ])
              end
            end
        end
      end
    end
  end

  @doc """
  rpc wrapper, support for define macro.
  """
  def rpc_call({nodes, mod, fun}, args)
  when is_list(args) and (is_list(nodes) or is_tuple(nodes)) and is_atom(mod) and is_atom(fun) do
    node = select_node(nodes, args)

    prefix_log = "common_lib, account helper, rpc_call, node: #{inspect node}, #{inspect mod}/#{inspect fun}/#{length(args)}, args: #{inspect args}"

    Logger.debug(prefix_log <> ", call")

    Rpc.call(node, mod, fun, args)
  end

    @doc """
  rpc wrapper, support for define macro.
  """
  def rpc_call_error_handling({nodes, mod, fun}, args)
  when is_list(args) and is_list(nodes) and is_atom(mod) and is_atom(fun) do
    node = select_node(nodes, args)

    prefix_log = "common_lib, account helper, rpc_call, node: #{inspect node}, #{inspect mod}/#{inspect fun}/#{length(args)}, args: #{inspect args}"

    try do
      Logger.debug(prefix_log <> ", call")

      case Rpc.call(node, mod, fun, args) do
        {:error, reason} ->
          Logger.error(prefix_log <> ", error: #{inspect(reason)}")
          false
        result ->
          Logger.info(prefix_log <> ", result: #{inspect result}")
          {:ok, result}
      end
    rescue
      e ->
        Logger.error(prefix_log <> ", error: #{inspect(e)}")
        {:error, e}
    catch
      e ->
        Logger.error(prefix_log <> ", catched unknown throw exception, #{inspect(e)}")
        {:error, e}
    end
  end

  defp select_node({mod, fun, args}, _args) do
    apply(mod, fun, args)
  end
  defp select_node(nodes, _args) do
    # TO-DO: implement real function
    Enum.random(nodes)
  end

  def get_config!(app_name, config_name, :nodes) do
      config = get_config!(app_name, config_name)

      case config[:nodes] do
        [] ->
          raise RpcWrapperError, "rpc_wrapper not configured for #{app_name}"
        {mod, fun, args} = mfa when is_atom(mod) and is_atom(fun) and is_list(args) ->
          mfa
        nodes when is_list(nodes) ->
          nodes
      end
  end

  def get_config!(app_name, config_name, :module) do
    config = get_config!(app_name, config_name)

    case config[:module] do
      [] ->
        raise RpcWrapperError, "rpc_wrapper missed configured for :module in #{app_name}/#{config_name}"
      mod when is_atom(mod) ->
        mod
    end
  end

  def get_config!(app_name, config_name, :functions) do
    config = get_config!(app_name, config_name)

    case config[:functions] do
      [] ->
        raise RpcWrapperError, "rpc_wrapper missed configured for :functions in #{app_name}/#{config_name}"
      list when is_list(list) ->
        Enum.map(list, fn
          {fun, arity} when is_atom(fun) and is_integer(arity) ->
            {fun, arity}
          {fun, new_name, arity} when is_atom(fun) and is_atom(new_name) and is_integer(arity) ->
            {fun, new_name, arity}
          other ->
            raise RpcWrapperError, "rpc_wrapper incorrected config for :functions in #{app_name}/#{config_name}, required tuple {atom, integer}/{atom, atom, integer}, but get #{inspect(other)}"
          end)
    end
  end

  defp get_config!(app_name, config_name) do
    case Application.get_env(app_name, config_name) do
      nil ->
        raise RpcWrapperError, "rpc_wrapper not configured for #{app_name}"
      config ->
        config
    end
  end
end
