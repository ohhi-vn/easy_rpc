defmodule EasyRpc.DefRpc do
  @moduledoc """
  This is second way to add a rpc to local module.
  In this way, you need declare all rpc functions in a module.
  Configs for nodes (list of node or {Module, :function, args}) can put to config.exs for runtime.exs file.

  ## GUIDE

  ### Add config for DefRpc

  Add config to config file in your project.

  ```Elixir
  config :simple_example, :remote_defrpc,
    nodes: [:"remote@127.0.0.1"],  # or using {module, function, args} like: {ClusterHelper, :get_nodes, [:remote_api]},
    select_mode: :round_robin # default is :random
    sticky_node: true # default is false
  ```

  Explain config:

  `:nodes` List of nodes, or {module, function, args} on local node.

  `:select_mode` Select node mode, default is :random. Support for  [:random, :round_robin, :hash].
    :round_robin will use per process to select node.
    :hash will using :erlang.phash2 to select node in list, data is arguments of function.

  `:sticky_node` If set to true, the node will be sticky for each call. Default is false.

  Note: `sticky_node` & `round_robin` are supported for rpc per process only.

  ### Using DefRpc in your module

  Add your global config for function & config info.

  ```Elixir
    use EasyRpc.DefRpc,
      otp_app: :simple_example,
      config_name: :remote_defrpc,
      # Remote module name
      module: RemoteNode.Interface,
      timeout: 1000,
      retry: 0
  ```

  Explain:

  `:otp_app` Application name for config.

  `:config_name` Config name for rpc.

  `:module` Remote module name.

  `:timeout` Timeout for rpc, default for all functions. If set timeout for function, it will override this value.

  `:retry` Retry times for rpc, default for all functions. If set retry for function, it will override this value.

  `:error_handling` Enable error handling (catch all) or not. In case of retry > 0, error_handling will be always true.

  ### Define rpc functions

  ```Elixir
  defrpc :get_data
  defrpc :put_data, args: 1
  defrpc :clear, args: 2, as: :clear_data, private: true
  defrpc :put_data, args: [:name], new_name: :put_with_retry, retry: 3, timeout: 1000
  ```

  Explain:

  `:args` Number of arguments for function. If set to 0 or missed, function will be defined without arguments.

  `:as` New name for function. If set, function will be defined with new name.

  `:private` If set to true, the function will be defined as private function. Default is false (public function).

  `:retry` Retry times for rpc, default for all functions. If set retry for function, it will override this value.

  `:timeout` Timeout for rpc, default for all functions. If set timeout for function, it will override this value.

  `:error_handling` Enable error handling (catch all) or not. In case of retry > 0, error_handling will be always true.

  """

  alias EasyRpc.{RpcWrapperError, WrapperConfig, RpcCall}

  require Logger

  defmacro __using__(opts) do
    # using location for easily to debug & development.
    quote location: :keep, bind_quoted: [opts: opts] do
      import EasyRpc.DefRpc

      # get options from `use`
      @rpc_wrapper_app_name Keyword.get(opts, :otp_app)
      @rpc_wrapper_config_name Keyword.get(opts, :config_name)
      @rpc_fun_private Keyword.get(opts, :private, false)

      @rpc_wrapper_config WrapperConfig.load_from_options!(opts)
    end
  end

  @spec defrpc(any()) :: {:__block__, [], [{:=, [], [...]} | {:__block__, [], [...]}, ...]}
  defmacro defrpc(fun, fun_opts \\ []) do
    quote bind_quoted: [fun: fun, fun_opts: fun_opts] do
      fun_orig = fun
      fun_name = Keyword.get(fun_opts, :as, fun_orig)
      fun_is_private = Keyword.get(fun_opts, :private, @rpc_fun_private)

      fun_timeout = Keyword.get(fun_opts, :timeout, @rpc_wrapper_config.timeout)
      fun_retry = Keyword.get(fun_opts, :retry, @rpc_wrapper_config.retry)

      fun_arity =
        case Keyword.get(fun_opts, :args, 0) do
          0 -> 0
          [] -> 0
          n when is_integer(n) and n >= 0 -> n
          list_args when is_list(list_args) ->
            list_args
          unknown ->
            raise RpcWrapperError, "rpc_wrapper incorrected :args (required: 0, non negative integer, list of atom) but get #{inspect(unknown)}"
        end

      # always use error_handling if retry > 0
      fun_error_handling =
        if fun_retry > 0 do
          true
        else
          Keyword.get(fun_opts, :error_handling, @rpc_wrapper_config.error_handling)
        end

      fun_config = Macro.escape(%{@rpc_wrapper_config | timeout: fun_timeout, retry: fun_retry, error_handling: fun_error_handling})

      case fun_arity do
        0 ->
          # funtion without arguments
          if fun_is_private do
            defp unquote(fun_name)() do
              RpcCall.rpc_call_dynamic(unquote(fun_config), {@rpc_wrapper_app_name, @rpc_wrapper_config_name}, {unquote(fun_orig), []})
            end
          else
            def unquote(fun_name)() do
              RpcCall.rpc_call_dynamic(unquote(fun_config), {@rpc_wrapper_app_name, @rpc_wrapper_config_name}, {unquote(fun_orig), []})
            end
          end

        n when is_integer(n) ->
          # function with arguments
          if fun_is_private do
            defp unquote(fun_name)(unquote_splicing(Enum.map(1..n, &Macro.var(:"arg_#{&1}", nil)))) do
              RpcCall.rpc_call_dynamic(unquote(fun_config), {@rpc_wrapper_app_name, @rpc_wrapper_config_name},
                {unquote(fun_orig), [unquote_splicing(Enum.map(1..n, &Macro.var(:"arg_#{&1}", nil)))]})
            end

          else
            def unquote(fun_name)(unquote_splicing(Enum.map(1..n, &Macro.var(:"arg_#{&1}", nil)))) do
              RpcCall.rpc_call_dynamic(unquote(fun_config), {@rpc_wrapper_app_name, @rpc_wrapper_config_name},
                {unquote(fun_orig), [unquote_splicing(Enum.map(1..n, &Macro.var(:"arg_#{&1}", nil)))]})
            end
          end

        list_args ->
          if fun_is_private do
            defp unquote(fun_name)(unquote_splicing(Enum.map(list_args, &Macro.var(&1, nil)))) do
              RpcCall.rpc_call_dynamic( unquote(fun_config), {@rpc_wrapper_app_name, @rpc_wrapper_config_name},
                {unquote(fun_orig), [unquote_splicing(Enum.map(list_args, &Macro.var(&1, nil)))]})
            end
          else
            def unquote(fun_name)(unquote_splicing(Enum.map(list_args, &Macro.var(&1, nil)))) do
              RpcCall.rpc_call_dynamic(unquote(fun_config), {@rpc_wrapper_app_name, @rpc_wrapper_config_name},
                {unquote(fun_orig), [unquote_splicing(Enum.map(list_args, &Macro.var(&1, nil)))]})
            end
          end
        end
      end
  end
end
