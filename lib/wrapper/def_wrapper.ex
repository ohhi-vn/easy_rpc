defmodule EasyRpc.DefRpc do
  @moduledoc """
  Declarative per-function RPC wrapper via the `defrpc` macro.

  Node config is loaded at **call time** (via `execute_dynamic/4`),
  so topology changes in `runtime.exs` take effect without recompiling.

  ## Config example

      config :my_app, :remote_defrpc,
        nodes: [:"remote@127.0.0.1"],
        select_mode: :round_robin,
        sticky_node: true

  ## Module setup

      defmodule MyApi do
        use EasyRpc.DefRpc,
          otp_app: :my_app,
          config_name: :remote_defrpc,
          module: RemoteNode.Interface,
          timeout: 1_000,
          retry: 0

        defrpc :get_data
        defrpc :put_data, args: 1
        defrpc :clear, args: 2, as: :clear_data, private: true
        defrpc :put_data, args: [:name], new_name: :put_with_retry, retry: 3, timeout: 1_000
      end

  ## Options for `defrpc`

  - `:args`           - Arity as integer, `[]`, or list of arg-name atoms (default: `0`)
  - `:as` / `:new_name` - Override the generated function name
  - `:private`        - Generate as `defp` (default: `false`)
  - `:retry`          - Override global retry count
  - `:timeout`        - Override global timeout
  - `:error_handling` - Override global error-handling flag
  """

  alias EasyRpc.{WrapperConfig, RpcCall, Utils.FunctionGenerator}

  require Logger

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      import EasyRpc.DefRpc, only: [defrpc: 1, defrpc: 2]

      @rpc_app_name Keyword.fetch!(opts, :otp_app)
      @rpc_config_name Keyword.fetch!(opts, :config_name)
      @rpc_global_private Keyword.get(opts, :private, false)

      # Validates module/timeout/retry/error_handling from `use` opts at compile time.
      @rpc_global_config WrapperConfig.load_from_options!(opts)
    end
  end

  defmacro defrpc(fun, fun_opts \\ []) do
    quote bind_quoted: [fun: fun, fun_opts: fun_opts] do
      alias EasyRpc.{RpcCall, Utils.FunctionGenerator}

      fun_name = FunctionGenerator.resolve_function_name(fun, fun_opts)
      fun_is_private = FunctionGenerator.is_private?(fun_opts) or @rpc_global_private
      fun_arity = FunctionGenerator.parse_arity(Keyword.get(fun_opts, :args, 0))
      fun_config = Macro.escape(FunctionGenerator.merge_config(@rpc_global_config, fun_opts))
      arg_vars = FunctionGenerator.generate_arg_vars(fun_arity)
      config_ref = {@rpc_app_name, @rpc_config_name}

      if fun_is_private do
        defp unquote(fun_name)(unquote_splicing(arg_vars)) do
          RpcCall.execute_dynamic(
            unquote(fun_config),
            unquote(config_ref),
            unquote(fun),
            [unquote_splicing(arg_vars)]
          )
        end
      else
        def unquote(fun_name)(unquote_splicing(arg_vars)) do
          RpcCall.execute_dynamic(
            unquote(fun_config),
            unquote(config_ref),
            unquote(fun),
            [unquote_splicing(arg_vars)]
          )
        end
      end
    end
  end
end
