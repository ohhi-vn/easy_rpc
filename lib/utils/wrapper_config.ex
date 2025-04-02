defmodule EasyRpc.WrapperConfig do
  @moduledoc false

  alias EasyRpc.{ConfigError, NodeSelector}

  alias __MODULE__

  defstruct [
    node_selector: nil,
    module: nil,
    timeout: 5_000,
    retry: 0,
    error_handling: false,
    functions: nil
  ]

  def load_config!(app_name, config_name) do
    config = Application.get_env(app_name, config_name)

    if config == nil do
      raise ConfigError, "not found configured for #{app_name}"
    end

    %WrapperConfig{
      node_selector: NodeSelector.load_config!(app_name, config_name),
      module: Keyword.get(config, :module),
      timeout: Keyword.get(config, :timeout, 5_000),
      retry: Keyword.get(config, :retry, 0),
      error_handling: Keyword.get(config, :error_handling, false),
      functions: Keyword.get(config, :functions, [])
    }
    |> verify_config!()
  end

  def load_from_options!(options) do
    node_selector = Keyword.get(options, :node_selector)

    %WrapperConfig{
      node_selector: node_selector,
      module: Keyword.get(options, :module),
      timeout: Keyword.get(options, :timeout, 5_000),
      retry: Keyword.get(options, :retry, 0),
      error_handling: Keyword.get(options, :error_handling, false),
      functions: Keyword.get(options, :functions, [])
    }
    |> verify_config!()
  end

  def new!(node_selector = %NodeSelector{}, module, timeout \\ 5_000, retry \\ 0, error_handling \\ false) do
    %WrapperConfig{
      node_selector: node_selector,
      module: module,
      timeout: timeout,
      retry: retry,
      error_handling: error_handling
    }
    |> verify_config!()
  end

  ## Private functions ##

  defp verify_config!(config) do
    case config.node_selector do
      %NodeSelector{} -> :ok
      nil -> :ok
      _ ->
        raise ConfigError, "incorrected config for :node_selector, required %NodeSelector{}, but get #{inspect(config.node_selector)}"
    end

    if (not is_atom(config.module)) or (config.module == nil) do
      raise ConfigError, "incorrected config for :remote_module, required atom, but get #{inspect(config.module)}"
    end

    case  config.timeout do
      n when is_integer(n) and n > 0 ->
        :ok
      :infinity ->
        :ok
      _ ->
        raise ConfigError, "incorrected config for :timeout (required: non negative integer) but get #{inspect(config.timeout)}"
    end

    if not is_integer(config.retry) or config.retry < 0 do
      raise ConfigError, "incorrected config for :retry (required: non negative integer) but get #{inspect(config.retry)}"
    end

    if not is_boolean(config.error_handling) do
      raise ConfigError, "incorrected config for :error_handling (required: boolean) but get #{inspect(config.error_handling)}"
    end

    if not is_list(config.functions) do
      raise ConfigError, "incorrected config for :functions, required list of atom, but get #{inspect(config.functions)}"
    end

    Enum.each(config.functions, fn
      {fun, arity} ->
        if not is_atom(fun) or not is_integer(arity) or arity < 0 do
          raise ConfigError, "incorrected config for :functions, required list of {atom, non negative integer}, but get #{inspect({fun, arity})}"
        end
      {fun, arity, opts} ->
        if not is_atom(fun) or not is_integer(arity) or arity < 0 do
          raise ConfigError, "incorrected config for :functions, required list of {atom, non negative integer}, but get #{inspect({fun, arity})}"
        end
        if not Keyword.keyword?(opts) do
          raise ConfigError, "incorrected config for :functions, required list of {atom, non negative integer, list}, but get #{inspect({fun, arity, opts})}"
        end
    end)

    config
  end
end
