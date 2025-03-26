defmodule EasyRpc.RpcWrapper do
  @moduledoc """
  This module provides a wrapper for RPC (Remote Procedure Call) in Elixir.
  It helps to call remote functions as local functions.
  The library uses macro to create a local function (declare by config).

  Currently, the you can wrapping multiple remote functions in a module.
  You can use same name or different name for remote functions.
  You also can have multiple wrappers for multiple remote modules.

  This solution for put all most things to config.exs file.
  Node list is fixed list but you can use {module, function, args} to get nodes dynamically.

  ## Guide

  ### Add config for RpcWrapper

  Put config to config.exs file in your project.
  For multi wrapper, you need to separate configs for each wrapper.

  Example:

  ```Elixir
  config :app_name, :wrapper_name,
    nodes: [:"test1@test.local", :"test2@test.local"],
    # or nodes: {MyModule, :get_nodes, []}
    error_handling: true, # enable error handling, global setting for all functions.
    select_mode: :random, # select node mode, global setting for all functions.
    timeout: 3_000, # timeout(ms) for each call, global setting for all functions, default is 5000ms.
    module: TargetApp.RemoteModule,
    functions: [
      # {function_name, arity, options \\ []}
      {:get_data, 1},
      {:put_data, 1, error_handling: false},
      {:clear, 2, [new_name: :clear_data, private: true]},
      {:put_data, 1, [new_name: :put_with_retry, retry: 3, timeout: 1_000]}
    ]
  ```

  Explain config:

  `:nodes` List of nodes, or {module, function, args} on local node.

  `:module` Module of remote functions on remote node.

  `:error_handling` Enable error handling (catch all) or not.

  `:select_mode` Select node mode, support for random, round_robin, hash.

  `:timeout` Timeout for rpc, default for all functions. If set timeout for function, it will override this value.

  `:functions` List of functions, each function is a tuple {function_name, arity} or {function_name, new_name, arity, opts}.

  `:options` Keyword of options, including new_name, retry, error_handling. Ex: [new_name: :clear_data, retry: 0, error_handling: true, timeout: 1_000].
  If retry is set, the function will retry n times when error occurs and error_handling will be applied.
  If error_handling is set, the function will catch all exceptions and return {:error, reason}.

  `:private` If set to true, the function will be defined as private function. Default is false (public function).

  ### RpcWrapper

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
  `:otp_app`, name of application will add config.
  `:config_name`, name of config in application config.
  """

  @fun_opts [:new_name, :retry, :error_handling, :private, :timeout]
  @select_strategies [:random, :round_robin, :hash]

  @fun_defaults_options [retry: 0]

  require Logger

  alias EasyRpc.RpcWrapperError

  alias EasyRpc.Utils.{RpcUtils, RpcCall}

  defmacro __using__(opts) do
    # using location for easily to debug & development.
    quote location: :keep, bind_quoted: [opts: opts] do
      rpc_wrapper_app_name = Keyword.get(opts, :otp_app)
      rpc_wrapper_config_name = Keyword.get(opts, :config_name)

      if rpc_wrapper_app_name == nil or rpc_wrapper_config_name == nil do
        raise RpcWrapperError, "rpc_wrapper, required :otp_app and :config_name"
      end

      rpc_wrapper_nodes = quote do RpcUtils.get_config!(unquote(rpc_wrapper_app_name), unquote(rpc_wrapper_config_name), :nodes) end
      rpc_wrapper_module = quote do RpcUtils.get_config!(unquote(rpc_wrapper_app_name), unquote(rpc_wrapper_config_name), :module) end
      rpc_wrapper_functions = RpcUtils.get_config!(rpc_wrapper_app_name, rpc_wrapper_config_name, :functions)

      rpc_select_strategy = quote do RpcUtils.get_config!(unquote(rpc_wrapper_app_name), unquote(rpc_wrapper_config_name), :select_mode) end
      rpc_error_handling =  RpcUtils.get_config!(rpc_wrapper_app_name, rpc_wrapper_config_name, :error_handling)
      rpc_timeout =  RpcUtils.get_config!(rpc_wrapper_app_name, rpc_wrapper_config_name, :timeout)

      for fun_info <- rpc_wrapper_functions do
        {fun, _, fun_opts} = fun_info

        fun_name = Keyword.get(fun_opts, :new_name, fun)
        fun_retry = Keyword.get(fun_opts, :retry, 0)
        fun_is_private = Keyword.get(fun_opts, :private, false)
        fun_timeout = Keyword.get(fun_opts, :timeout, rpc_timeout)

        # always use error_handling if retry > 0
        fun_error_handling =
          if fun_retry > 0 do
            true
          else
            Keyword.get(fun_opts, :error_handling, rpc_error_handling)
          end

        case fun_info do
          # funtion without arguments
          {fun, 0, fun_opts} ->
              if fun_is_private do
                defp unquote(fun_name)() do
                  RpcCall.rpc_call(
                    {unquote(fun_error_handling), unquote(fun_retry)},
                    {unquote(rpc_wrapper_module), unquote(fun), []},
                    {unquote(rpc_wrapper_nodes), unquote(rpc_select_strategy), unquote(fun_timeout)})
                end
              else
                def unquote(fun_name)() do
                  RpcCall.rpc_call(
                    {unquote(fun_error_handling), unquote(fun_retry)},
                    {unquote(rpc_wrapper_module), unquote(fun), []},
                    {unquote(rpc_wrapper_nodes), unquote(rpc_select_strategy), unquote(fun_timeout)})
                end
              end

          {fun, arity, fun_opts} ->
            if fun_is_private do

              defp unquote(fun_name)(unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ) do
                RpcCall.rpc_call(
                  {unquote(fun_error_handling), unquote(fun_retry)},
                  {unquote(rpc_wrapper_module), unquote(fun),  [unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil)))]},
                  {unquote(rpc_wrapper_nodes), unquote(rpc_select_strategy), unquote(fun_timeout)})
              end
            else
              def unquote(fun_name)(unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil))) ) do
                  RpcCall.rpc_call(
                    {unquote(fun_error_handling), unquote(fun_retry)},
                    {unquote(rpc_wrapper_module), unquote(fun),  [unquote_splicing(Enum.map(1..arity, &Macro.var(:"arg_#{&1}", nil)))]},
                    {unquote(rpc_wrapper_nodes), unquote(rpc_select_strategy), unquote(fun_timeout)})
              end
            end
        end
      end
    end
  end

end
