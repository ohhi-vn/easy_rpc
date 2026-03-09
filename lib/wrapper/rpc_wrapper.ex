defmodule EasyRpc.RpcWrapper do
  @moduledoc """
  Configuration-driven RPC wrapper.

  Generates local functions from a function list defined in application config.
  All RPC definitions live in one place (config.exs / runtime.exs), keeping
  the host module clean.

  ## Config example

      config :app_name, :wrapper_name,
        nodes: [:"node1@host", :"node2@host"],
        select_mode: :random,
        sticky_node: false,
        error_handling: true,
        timeout: 3_000,
        module: TargetApp.RemoteModule,
        functions: [
          {:get_data, 1},
          {:put_data, 1, [error_handling: false]},
          {:clear, 2, [new_name: :clear_data, private: true]},
          {:put_data, 1, [new_name: :put_with_retry, retry: 3, timeout: 1_000]}
        ]

  ## Usage

      defmodule DataHelper do
        use EasyRpc.RpcWrapper,
          otp_app: :app_name,
          config_name: :wrapper_name

        def process_remote() do
          case get_data("key") do
            {:ok, data}     -> data
            {:error, error} -> raise EasyRpc.Error.format(error)
          end
        end
      end
  """

  alias EasyRpc.{WrapperConfig, RpcCall, Utils.FunctionGenerator}

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      alias EasyRpc.{WrapperConfig, RpcCall, Utils.FunctionGenerator}

      rpc_config =
        WrapperConfig.load_config!(
          Keyword.fetch!(opts, :otp_app),
          Keyword.fetch!(opts, :config_name)
        )

      for fun_info <- rpc_config.functions do
        {fun_orig, arity, fun_opts} = FunctionGenerator.normalize_function_info(fun_info)

        fun_name = FunctionGenerator.resolve_function_name(fun_orig, fun_opts)
        fun_is_private = FunctionGenerator.is_private?(fun_opts)
        fun_config = Macro.escape(FunctionGenerator.merge_config(rpc_config, fun_opts))
        arg_vars = FunctionGenerator.generate_arg_vars(arity)

        if fun_is_private do
          defp unquote(fun_name)(unquote_splicing(arg_vars)) do
            RpcCall.execute(unquote(fun_config), unquote(fun_orig), [unquote_splicing(arg_vars)])
          end
        else
          def unquote(fun_name)(unquote_splicing(arg_vars)) do
            RpcCall.execute(unquote(fun_config), unquote(fun_orig), [unquote_splicing(arg_vars)])
          end
        end
      end
    end
  end
end
