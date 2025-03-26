defmodule EasyRpc.Utils.RpcUtils do
  @moduledoc false

  alias EasyRpc.RpcWrapperError

  # Strategy for select node
  @select_strategies [:random, :round_robin, :hash]

  # Default options for rpc function
  @fun_defaults_options [retry: 0]

  # Options supported for rpc function
  @fun_opts [:new_name, :retry, :error_handling, :private, :timeout]

  @spec select_node(atom() | [atom()] | {atom() | tuple(), atom(), list()}, any()) :: any()
  @doc false
  def select_node({mod, fun, args}, extra) do
    apply(mod, fun, args) |> select_node(extra)
  end
  def select_node(node, _) when is_atom(node) do
    node
  end
  def select_node(nodes, {strategy, module, data}) when is_list(nodes) do
    EasyRpc.NodeUtils.select_node(nodes, strategy, {module, data})
  end

  @doc false
  def valid_timeout!(timeout) do
    case timeout do
      nil ->
        5000 # default value
      :infinity ->
        :infinity
      n when is_integer(n) and n > 0 ->
        n
      unknown ->
        raise RpcWrapperError, "rpc_wrapper incorrected :timeout (required: infinity, non negative integer) but get #{inspect(unknown)}"
    end
  end

  @doc false
  def get_config!(app_name, config_name, :error_handling) do
    config = get_config!(app_name, config_name)

    case config[:error_handling] do
      nil ->
        false # default value
      mod when is_atom(mod) ->
        mod
    end
  end

  @doc false
  @spec get_config!(atom, atom, atom) :: any
  def get_config!(app_name, config_name, :nodes) do
      config = get_config!(app_name, config_name)

      case config[:nodes] do
        nil ->
          raise RpcWrapperError, "rpc_wrapper, not found configured for #{app_name}"
        {mod, fun, args} = mfa when is_atom(mod) and is_atom(fun) and is_list(args) ->
          mfa
        nodes when is_list(nodes) ->
          nodes
        unknown ->
          raise RpcWrapperError, "rpc_wrapper, #{inspect config_name}, incorrected config for :nodes, required list of atom, but get #{inspect(unknown)}"
      end
  end

  @doc false
  def get_config!(app_name, config_name, :module) do
    config = get_config!(app_name, config_name)

    case config[:module] do
      nil ->
        raise RpcWrapperError, "rpc_wrapper, #{inspect config_name}, missed config for :module"
      mod when is_atom(mod) ->
        mod
      unknown ->
        raise RpcWrapperError, "rpc_wrapper, #{inspect config_name}, incorrected config for :module, required atom, but get #{inspect(unknown)}"
    end
  end

  @doc false
  def get_config!(app_name, config_name, :functions) do
    config = get_config!(app_name, config_name)

    case config[:functions] do
      nil ->
        raise RpcWrapperError, "rpc_wrapper,  #{inspect config_name}, missed config for :functions"
      list when is_list(list) ->
        Enum.map(list, fn
          {fun, arity} when is_atom(fun) and is_integer(arity) and arity >= 0 ->
            {fun, arity, []}
          {fun, arity, opts} when is_atom(fun) and is_list(opts) and is_integer(arity) and arity >= 0 ->
            opts = Keyword.merge(@fun_defaults_options, opts)

            Enum.each(opts, fn {key, value} ->
              if not Enum.member?(@fun_opts, key) do
                raise RpcWrapperError, "rpc_wrapper, #{inspect config_name}, incorrected config for :functions, required opts #{inspect(@fun_opts)}, but get #{inspect(key)}"
              end

              case key do
                :timeout ->
                  value |> valid_timeout!()
                :retry ->
                  if not is_integer(value) or value < 0 do
                    raise RpcWrapperError, "rpc_wrapper, #{inspect config_name}, incorrected :retry option for #{inspect fun} :functions, required retry >= 0, but get #{inspect(value)}"
                  end
                :private ->
                  if not is_boolean(value) do
                    raise RpcWrapperError, "rpc_wrapper, #{inspect config_name}, incorrected :private option for #{inspect fun}, required boolean, but get #{inspect(value)}"
                  end
                :error_handling ->
                  if not is_boolean(value) do
                    raise RpcWrapperError, "rpc_wrapper,  #{inspect config_name}, incorrected :error_handling option for #{inspect fun}, required boolean, but get #{inspect(value)}"
                  end
                :new_name ->
                  if not is_atom(value) do
                    raise RpcWrapperError, "rpc_wrapper, #{inspect config_name}, incorrected :new_name option for #{inspect fun}, required atom, but get #{inspect(value)}"
                  end
              end
            end)
            {fun, arity, opts}
          other ->
            raise RpcWrapperError, "rpc_wrapper, #{inspect config_name}, unknown function option, required tuple {atom, integer}/{atom, integer, keyword}, but get #{inspect(other)}"
          end)
      unknown ->
        raise RpcWrapperError, "rpc_wrapper,  #{inspect config_name}, incorrected config for :functions, required list of tuple ({atom, integer}/{atom, integer, keyword}), but get #{inspect(unknown)}"
    end
  end

  def get_config!(app_name, config_name, :timeout) do
    config = get_config!(app_name, config_name)

    config[:timeout] |> valid_timeout!()
  end

  def get_config!(app_name, config_name, :select_mode) do
    config = get_config!(app_name, config_name)

    case config[:select_mode] do
      nil ->
        :random
      mod when is_atom(mod) and mod in @select_strategies ->
        mod
      unknown ->
        raise RpcWrapperError, "rpc_wrapper, #{inspect config_name}, incorrected config for :select_mode, required atom in #{inspect @select_strategies}, but get #{inspect(unknown)}"
    end
  end

  @doc false
  @spec get_config!(atom, atom) :: any
  def get_config!(app_name, config_name) do
    case Application.get_env(app_name, config_name) do
      nil ->
        raise RpcWrapperError, "rpc_wrapper, not found #{inspect config_name} for #{app_name}"
      config ->
        config
    end
  end

  @doc false
  @spec valid_strategy!(atom) :: any
  def valid_strategy!(strategy) do
    if not Enum.member?(@select_strategies, strategy) do
      raise RpcWrapperError, "rpc_wrapper incorrected config for strategy, required #{@select_strategies}, but get #{strategy}"
    end
  end
end
