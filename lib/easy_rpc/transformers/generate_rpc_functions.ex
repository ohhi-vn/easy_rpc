defmodule EasyRpc.Transformers.GenerateRpcFunctions do
  @moduledoc """
  Transformer that generates RPC wrapper functions from DSL definitions.

  This transformer:
  1. Reads the DSL state to get config and rpc_functions
  2. Generates public or private defs for each rpc_function entity
  3. Injects the function definitions into the module
  """

  use Spark.Dsl.Transformer

  alias EasyRpc.{RpcCall, NodeSelector, WrapperConfig, Utils.FunctionGenerator}
  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    # Get the module being compiled
    module = Transformer.get_persisted(dsl_state, :module)

    # Get config section
    config = get_config(dsl_state)

    # Get all rpc_function entities
    functions = Transformer.get_entities(dsl_state, [:rpc_functions])

    # Generate function definitions
    quotes =
      Enum.map(functions, fn fun_entity ->
        generate_function_quote(fun_entity, config, module)
      end)

    # Evaluate the quotes into the module
    {:ok, Transformer.eval(dsl_state, [], quotes)}
  end

  defp get_config(dsl_state) do
    # Extract config from DSL state
    nodes = Transformer.get_option(dsl_state, [:config], :nodes)
    nodes_provider = Transformer.get_option(dsl_state, [:config], :nodes_provider)
    select_mode = Transformer.get_option(dsl_state, [:config], :select_mode)
    sticky_node = Transformer.get_option(dsl_state, [:config], :sticky_node)
    module = Transformer.get_option(dsl_state, [:config], :module)
    timeout = Transformer.get_option(dsl_state, [:config], :timeout)
    retry = Transformer.get_option(dsl_state, [:config], :retry)
    sleep_before_retry = Transformer.get_option(dsl_state, [:config], :sleep_before_retry)
    error_handling = Transformer.get_option(dsl_state, [:config], :error_handling)
    enable_logging = Transformer.get_option(dsl_state, [:config], :enable_logging)

    # Create NodeSelector - using module name as id
    # Prefer nodes_provider (MFA) over static nodes list
    nodes_or_mfa = if nodes_provider do
      nodes_provider
    else
      nodes
    end

    node_selector = NodeSelector.new(nodes_or_mfa, module, select_mode, sticky_node)

    %WrapperConfig{
      node_selector: node_selector,
      module: module,
      timeout: timeout,
      retry: retry,
      sleep_before_retry: sleep_before_retry,
      error_handling: error_handling,
      enable_logging: enable_logging
    }
  end

  defp generate_function_quote(fun_entity, global_config, _module) do
    # Resolve function name (handle :new_name)
    fun_name = fun_entity.new_name || fun_entity.name
    arity = FunctionGenerator.parse_arity(fun_entity.arity)

    # Merge function-specific config with global config
    fun_opts = []
    fun_opts = if fun_entity.timeout, do: [{:timeout, fun_entity.timeout} | fun_opts], else: fun_opts
    fun_opts = if fun_entity.retry, do: [{:retry, fun_entity.retry} | fun_opts], else: fun_opts
    fun_opts = if fun_entity.sleep_before_retry, do: [{:sleep_before_retry, fun_entity.sleep_before_retry} | fun_opts], else: fun_opts
    fun_opts = if fun_entity.error_handling != nil, do: [{:error_handling, fun_entity.error_handling} | fun_opts], else: fun_opts

    config = FunctionGenerator.merge_config(global_config, fun_opts)

    # Generate argument variables
    arg_vars = FunctionGenerator.generate_arg_vars(arity)

    # Determine if private
    is_private = fun_entity.private

    # Generate the function definition
    if is_private do
      quote do
        defp unquote(fun_name)(unquote_splicing(arg_vars)) do
          unquote(__MODULE__).execute_rpc(
            unquote(Macro.escape(config)),
            unquote(fun_entity.name),
            [unquote_splicing(arg_vars)]
          )
        end
      end
    else
      quote do
        def unquote(fun_name)(unquote_splicing(arg_vars)) do
          unquote(__MODULE__).execute_rpc(
            unquote(Macro.escape(config)),
            unquote(fun_entity.name),
            [unquote_splicing(arg_vars)]
          )
        end
      end
    end
  end

  @doc false
  def execute_rpc(config, function, args) do
    RpcCall.execute(config, function, args)
  end
end
