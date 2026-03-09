defmodule EasyRpc.Utils.FunctionGenerator do
  @moduledoc """
  Compile-time helpers for generating RPC wrapper functions.

  Used by both `EasyRpc.RpcWrapper` and `EasyRpc.DefRpc` to ensure
  consistent behaviour when expanding macros.

  Responsibilities:

  - Normalising function info tuples into `{name, arity, opts}`
  - Resolving final function names (`:as` / `:new_name` support)
  - Merging per-function opts over global `WrapperConfig`
  - Generating AST variable lists for macro `def` bodies
  - Validating per-function option values
  """

  alias EasyRpc.WrapperConfig

  @type function_opts :: keyword()
  @type function_info ::
          {name :: atom(), arity :: non_neg_integer() | [atom()], opts :: keyword()}

  @doc """
  Normalises a function spec tuple into `{name, arity_or_args, opts}`.

  Raises `EasyRpc.Error` on unrecognised formats.

  ## Examples

      iex> normalize_function_info({:get_user, 1})
      {:get_user, 1, []}

      iex> normalize_function_info({:get_user, 1, [retry: 3]})
      {:get_user, 1, [retry: 3]}
  """
  @spec normalize_function_info(tuple()) :: function_info()
  def normalize_function_info({fun, arity}) when is_atom(fun) and is_integer(arity),
    do: {fun, arity, []}

  def normalize_function_info({fun, arity, opts})
      when is_atom(fun) and is_integer(arity) and is_list(opts),
      do: {fun, arity, opts}

  def normalize_function_info(invalid),
    do:
      raise(
        EasyRpc.Error.config_error(
          "Invalid function spec: #{inspect(invalid)} — expected {atom, integer} or {atom, integer, keyword}"
        )
      )

  @doc """
  Resolves the effective function name, honouring `:as` and `:new_name` opts.

  ## Examples

      iex> resolve_function_name(:get_user, [])
      :get_user

      iex> resolve_function_name(:get_user, [as: :fetch_user])
      :fetch_user
  """
  @spec resolve_function_name(atom(), function_opts()) :: atom()
  def resolve_function_name(original, opts),
    do: Keyword.get(opts, :as) || Keyword.get(opts, :new_name, original)

  @doc """
  Returns `true` if the function should be generated as private.
  """
  @spec is_private?(function_opts()) :: boolean()
  def is_private?(opts), do: Keyword.get(opts, :private, false)

  @doc """
  Merges per-function opts over `global_config`, returning a new `WrapperConfig`.

  Automatically sets `error_handling: true` when `retry > 0`.

  ## Examples

      merge_config(%WrapperConfig{retry: 0, timeout: 5000, error_handling: false}, [retry: 3])
      #=> %WrapperConfig{retry: 3, timeout: 5000, error_handling: true}
  """
  @spec merge_config(WrapperConfig.t(), function_opts()) :: WrapperConfig.t()
  def merge_config(%WrapperConfig{} = global, fun_opts) do
    retry = Keyword.get(fun_opts, :retry, global.retry)
    timeout = Keyword.get(fun_opts, :timeout, global.timeout)

    error_handling =
      if retry > 0,
        do: true,
        else: Keyword.get(fun_opts, :error_handling, global.error_handling)

    %{global | retry: retry, timeout: timeout, error_handling: error_handling}
  end

  @doc """
  Validates all keys and values in a per-function opts list.
  Raises `EasyRpc.Error` on any unknown key or bad value.

  Valid keys: `:as`, `:new_name`, `:retry`, `:timeout`, `:error_handling`,
  `:private`, `:args`.
  """
  @spec validate_function_opts!(function_opts()) :: :ok
  def validate_function_opts!(opts) when is_list(opts) do
    valid_keys = [:as, :new_name, :retry, :timeout, :error_handling, :private, :args]

    Enum.each(opts, fn {key, value} ->
      unless key in valid_keys do
        raise EasyRpc.Error.config_error(
                "Unknown function option #{inspect(key)} — valid: #{inspect(valid_keys)}"
              )
      end

      validate_function_opt_value!(key, value)
    end)

    :ok
  end

  @doc """
  Parses an arity specification into a canonical form.

  - Integer  → used directly
  - `[]`     → `0`
  - `[atom]` → list of named arg atoms

  Raises `EasyRpc.Error` on invalid input.
  """
  @spec parse_arity(integer() | list()) :: non_neg_integer() | [atom()]
  def parse_arity(0), do: 0
  def parse_arity([]), do: 0
  def parse_arity(n) when is_integer(n) and n > 0, do: n

  def parse_arity(list) when is_list(list) do
    unless Enum.all?(list, &is_atom/1) do
      raise EasyRpc.Error.config_error(
              "Invalid args list — all elements must be atoms, got: #{inspect(list)}"
            )
    end

    list
  end

  def parse_arity(invalid),
    do:
      raise(
        EasyRpc.Error.config_error(
          "Invalid arity — expected non-negative integer or list of atoms, got: #{inspect(invalid)}"
        )
      )

  @doc """
  Generates AST variable nodes for use in macro-expanded `def` bodies.

  ## Examples

      generate_arg_vars(2)
      #=> [Macro.var(:arg_1, nil), Macro.var(:arg_2, nil)]

      generate_arg_vars([:user_id, :name])
      #=> [Macro.var(:user_id, nil), Macro.var(:name, nil)]
  """
  @spec generate_arg_vars(non_neg_integer() | [atom()]) :: [Macro.t()]
  def generate_arg_vars(0), do: []

  def generate_arg_vars(n) when is_integer(n) and n > 0,
    do: Enum.map(1..n, &Macro.var(:"arg_#{&1}", nil))

  def generate_arg_vars(names) when is_list(names),
    do: Enum.map(names, &Macro.var(&1, nil))

  ## Private

  defp validate_function_opt_value!(:as, v) when is_atom(v), do: :ok
  defp validate_function_opt_value!(:new_name, v) when is_atom(v), do: :ok
  defp validate_function_opt_value!(:private, v) when is_boolean(v), do: :ok
  defp validate_function_opt_value!(:error_handling, v) when is_boolean(v), do: :ok
  defp validate_function_opt_value!(:retry, v) when is_integer(v) and v >= 0, do: :ok
  defp validate_function_opt_value!(:timeout, :infinity), do: :ok
  defp validate_function_opt_value!(:timeout, v) when is_integer(v) and v > 0, do: :ok

  defp validate_function_opt_value!(:args, v) do
    parse_arity(v)
    :ok
  rescue
    _ -> raise EasyRpc.Error.config_error("Invalid value for :args option: #{inspect(v)}")
  end

  defp validate_function_opt_value!(key, value),
    do: raise(EasyRpc.Error.config_error("Invalid value for #{inspect(key)}: #{inspect(value)}"))
end
