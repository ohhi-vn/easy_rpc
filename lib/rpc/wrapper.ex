defmodule EasyRpc.RpcWrapper do
  @moduledoc """
  This module provides a wrapper for RPC (Remote Procedure Call) in Elixir.
  It helps to call remote functions as local functions.
  The library uses macro to create a local function (declare by config).

  Currently, the you can wrapping multiple remote functions in a module.
  You can use same name or different name for remote functions.
  You also can have multiple wrappers for multiple remote modules.

  # Guide

  ## Add config for RpcWrapper

  Put config to config.exs file in your project.
  For multi wrapper, you need to separate configs for each wrapper.

  Example:

  ```Elixir
  config :app_name, :wrapper_name,
    nodes: [:"test1@test.local", :"test2@test.local"],
    # or nodes: {MyModule, :get_nodes, []}
    error_handling: true, # enable error handling, global setting for all functions.
    select_mode: :random, # select node mode, global setting for all functions.
    module: TargetApp.RemoteModule,
    functions: [
      # {function_name, arity, options \\ []}
      {:get_data, 1},
      {:put_data, 1, error_handling: false},
      {:clear, 2, [new_name: :clear_data]},
    ]
  ```

  Explain config:

  `:nodes` List of nodes, or {module, function, args} on local node.
  `:module` Module of remote functions on remote node.
  `:error_handling` Enable error handling (catch all) or not.
  `:select_mode` Select node mode, support for random, round_robin, hash.
  `:functions` List of functions, each function is a tuple {function_name, arity} or {function_name, new_name, arity, opts}.
  `:options` Keyword of options, including new_name, retry, error_handling. Ex: [new_name: :clear_data, retry: 3, error_handling: true].
    If retry is set, the function will retry n times when error occurs.
    Retry will be applied if function's option has error_handling: true or global setting has error_handling: true.

  ## RpcWrapper

  Usage:
  by using RpcWrapper in your module, you can call remote functions as local functions.

  Example:

  ```Elixir
  defmodule DataHelper do
  use EasyRpc.RpcWrapper,
    otp_app: :app_name,
    config_name: :wrapper_name

  def process_remote() do
    case get_data("key") do
      {:ok, data} ->
        # do something with data
      {:error, reason} ->
        # handle error
    end
  end
  ```

  Explain:
  `:otp_app`, name of application will add config
  `:config_name`, name of config in application config.
  """

  alias :erpc, as: Rpc

  @fun_opts [:new_name, :retry, :error_handling]
  @select_strategies [:random, :round_robin, :hash]

  @fun_defaults_options [retry: 0, error_handling: false]

  alias __MODULE__

  require Logger

  defmodule RpcWrapperError do
    defexception [:message]

    def raise_error(error) when is_binary(error) do
      raise RpcWrapperError, message: error
    end
  end

  defmacro __using__(opts) do
    # using location for easily to debug & development.
    quote location: :keep, bind_quoted: [opts: opts] do
      rpc_wrapper_app_name = Keyword.get(opts, :otp_app)
      rpc_wrapper_config_name = Keyword.get(opts, :config_name)
      rpc_error_handling = Keyword.get(opts, :error_handling, false)
      rpc_select_strategy = Keyword.get(opts, :select_mode, :random)

      EasyRpc.RpcWrapper.valid_strategy!(rpc_select_strategy)

      rpc_wrapper_nodes = quote do RpcWrapper.get_config!(unquote(rpc_wrapper_app_name), unquote(rpc_wrapper_config_name), :nodes) end
      rpc_wrapper_module = quote do RpcWrapper.get_config!(unquote(rpc_wrapper_app_name), unquote(rpc_wrapper_config_name), :module) end
      rpc_wrapper_functions = RpcWrapper.get_config!(rpc_wrapper_app_name, rpc_wrapper_config_name, :functions)

      for fun_info <- rpc_wrapper_functions do
        case fun_info do
          {fun, 0} ->
            if rpc_error_handling do
              def unquote(fun)() do
                RpcWrapper.rpc_call_error_handling({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module),
                   unquote(fun)}, [], unquote(rpc_select_strategy))
              end
            else
              def unquote(fun)() do
                RpcWrapper.rpc_call({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module), unquote(fun)},
                [], unquote(rpc_select_strategy))
              end
            end
          {fun, arity} ->
            if rpc_error_handling do
              def unquote(fun)(unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ) do
                RpcWrapper.rpc_call_error_handling({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module),
                   unquote(fun)}, [unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil)))],
                   unquote(rpc_select_strategy))
              end
            else
              def unquote(fun)(unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ) do
                RpcWrapper.rpc_call({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module), unquote(fun)},
                [unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil)))],
                unquote(rpc_select_strategy))
              end
            end

          {fun, 0, fun_opts} ->
              fun_name = Keyword.get(fun_opts, :new_name, fun)
              fun_error_handling = Keyword.get(fun_opts, :error_handling, rpc_error_handling)
              fun_retry = Keyword.get(fun_opts, :retry, 0)

              if fun_error_handling do
                def unquote(fun_name)() do
                  RpcWrapper.rpc_call_error_handling({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module),
                    unquote(fun)}, [], unquote(rpc_select_strategy), unquote(fun_retry))
                end
              else
                def unquote(fun_name)() do
                  RpcWrapper.rpc_call({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module), unquote(fun)},
                    [], unquote(rpc_select_strategy))
                end
              end

          {fun, arity, fun_opts} ->
            fun_name = Keyword.get(fun_opts, :new_name, fun)
            fun_error_handling = Keyword.get(fun_opts, :error_handling, rpc_error_handling)
            fun_retry = Keyword.get(fun_opts, :retry, 0)

            if fun_error_handling do
              def unquote(fun_name)(unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ) do
                RpcWrapper.rpc_call_error_handling({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module),
                  unquote(fun)}, [unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil)))],
                  unquote(rpc_select_strategy), unquote(fun_retry))
              end
            else
              def unquote(fun_name)(unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ) do
                RpcWrapper.rpc_call({unquote(rpc_wrapper_nodes), unquote(rpc_wrapper_module), unquote(fun)},
                  [unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil)))],
                  unquote(rpc_select_strategy))
              end
            end
        end
      end
    end
  end

  @doc """
  rpc wrapper, support for define macro.
  """
  @spec rpc_call({list | tuple, atom, atom}, list, atom) :: any
  def rpc_call({nodes, mod, fun}, args, strategy \\ :random)
  when is_list(args) and (is_list(nodes) or is_tuple(nodes)) and is_atom(mod) and is_atom(fun) do
    node = EasyRpc.NodeUtils.select_node(nodes, strategy, {mod, args})

    prefix_log = "easy_rpc, rpcwrapper, rpc_call, node: #{inspect node}, #{inspect mod}/#{inspect fun}/#{length(args)}, args: #{inspect args}"

    Logger.debug(prefix_log <> ", call")

    Rpc.call(node, mod, fun, args)
  end

  @doc """
  rpc wrapper, support for define macro.
  """
  @spec rpc_call_error_handling({list | tuple, atom, atom}, list, atom) :: any
  def rpc_call_error_handling({nodes, mod, fun}, args, strategy \\ :random, retry \\ 0)
  when is_list(args) and is_list(nodes) and is_atom(mod) and is_atom(fun) do
    node = select_node(nodes, {strategy, mod, args})

    prefix_log = "easy_rpc, rpcwrapper, rpc_call, node: #{inspect node}, #{inspect mod}/#{inspect fun}/#{length(args)}, args: #{inspect args}"

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
        if retry > 0 do
          Logger.error(prefix_log <> ", retry: #{inspect(retry)} (decrease), error: #{inspect(e)}")
          rpc_call_error_handling({nodes, mod, fun}, args, strategy, retry - 1)
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

  @doc """
  Get config from application env.
  """
  @spec get_config!(atom, atom, atom) :: any
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
          {fun, arity} when is_atom(fun) and is_integer(arity) and arity >= 0 ->
            {fun, arity}
          {fun, arity, opts} when is_atom(fun) and is_list(opts) and is_integer(arity) and arity >= 0 ->
            opts = Keyword.merge(@fun_defaults_options, opts)
            Enum.each(opts, fn {key, _value} ->
              if not Enum.member?(@fun_opts, key) do
                raise RpcWrapperError, "rpc_wrapper incorrected config for :functions in #{app_name}/#{config_name}, required opts #{inspect(@fun_opts)}, but get #{inspect(key)}"
              end
            end)
            {fun, arity, opts}
          other ->
            raise RpcWrapperError, "rpc_wrapper incorrected config for :functions in #{app_name}/#{config_name}, required tuple {atom, integer}/{atom, atom, integer}, but get #{inspect(other)}"
          end)
    end
  end

  @doc """
  Get config from application env.
  """
  @spec get_config!(atom, atom) :: any
  def get_config!(app_name, config_name) do
    case Application.get_env(app_name, config_name) do
      nil ->
        raise RpcWrapperError, "rpc_wrapper not configured for #{app_name}"
      config ->
        config
    end
  end

  @doc """
  Validate select strategy.
  """
  @spec valid_strategy!(atom) :: any
  def valid_strategy!(strategy) do
    if not Enum.member?(@select_strategies, strategy) do
      raise RpcWrapperError, "rpc_wrapper incorrected config for strategy, required strategies #{@select_strategies}, but get #{strategy}"
    end
  end

  ## Private functions ##

  defp select_node({mod, fun, args}, _) do
    apply(mod, fun, args)
  end
  defp select_node(node, _) when is_atom(node) do
    node
  end
  defp select_node(nodes, {strategy, module, data}) when is_list(nodes) do
    EasyRpc.NodeUtils.select_node(nodes, strategy, {module, data})
  end

end
