defmodule EasyRpc.Dsl do
  @moduledoc """
  Spark DSL extension for EasyRpc.

  Defines the DSL structure for declaring RPC functions with support for:
  - Node configuration (nodes, select_mode, sticky_node)
  - Global settings (timeout, retry, error_handling)
  - Per-function configuration via `rpc_function` entities
  """

  alias Spark.Builder.{Entity, Field, Section}

  @type t :: %{
          :node_selector => EasyRpc.NodeSelector.t(),
          :module => module(),
          :timeout => pos_integer() | :infinity,
          :retry => non_neg_integer(),
          :sleep_before_retry => non_neg_integer(),
          :error_handling => boolean(),
          :functions => [EasyRpc.Dsl.Function.t()]
        }

  defmodule Function do
    @moduledoc """
    Struct representing an RPC function definition in the DSL.
    """
    defstruct [
      :name,
      :arity,
      :new_name,
      :private,
      :retry,
      :timeout,
      :sleep_before_retry,
      :error_handling,
      :enable_logging,
      :__identifier__,
      :__spark_metadata__
    ]
  end

  @function_entity Entity.new(:rpc_function, Function,
    describe: "An RPC function to be wrapped",
    args: [:name, :arity],
    schema: [
      Field.new(:name, :atom, required: true, doc: "The name of the remote function"),
      Field.new(:arity, :any,
        required: true,
        doc: "The arity (integer) or list of argument names (e.g., 2 or [:user_id, :name])"
      ),
      Field.new(:new_name, :atom, doc: "Override the generated function name (alias: :as)"),
      Field.new(:private, :boolean, default: false, doc: "Generate as private function (defp)"),
      Field.new(:retry, :integer, doc: "Override global retry count for this function"),
      Field.new(:timeout, :integer, doc: "Override global timeout for this function"),
      Field.new(:sleep_before_retry, :integer,
        doc: "Override global sleep before retry for this function"
      ),
      Field.new(:error_handling, :boolean,
        doc: "Override global error handling for this function"
      )
    ],
    identifier: :name
  )
  |> Entity.build!()

  @config_section Section.new(:config,
    describe: "Global RPC configuration",
    schema: [
      Field.new(:nodes, {:list, :atom},
        doc: "Static list of target node names (e.g., [:\"node1@host\", :\"node2@host\"])"
      ),
      Field.new(:nodes_provider, :mfa,
        doc: "Dynamic node discovery via MFA: {module, function, args} (alternative to :nodes)"
      ),
      Field.new(:select_mode, {:one_of, [:random, :round_robin, :hash]},
        default: :random,
        doc: "Node selection strategy"
      ),
      Field.new(:sticky_node, :boolean,
        default: false,
        doc: "Pin to the first selected node for the process lifetime"
      ),
      Field.new(:module, :atom, required: true, doc: "Remote module to call"),
      Field.new(:timeout, :integer,
        default: 5_000,
        doc: "Global timeout in ms (use :infinity for no timeout)"
      ),
      Field.new(:retry, :integer, default: 0, doc: "Global retry count (default: 0)"),
      Field.new(:sleep_before_retry, :integer, default: 0, doc: "Ms to wait before retry (default: 0)"),
      Field.new(:error_handling, :boolean,
        default: false,
        doc: "Return {:ok, result} tuples (default: false)"
      ),
      Field.new(:enable_logging, :boolean,
        default: true,
        doc: "Enable detailed logging (default: true)"
      )
    ],
    entities: []
  )
  |> Section.build!()

  @functions_section Section.new(:rpc_functions,
    describe: "RPC functions to wrap",
    schema: [],
    entities: [@function_entity]
  )
  |> Section.build!()

  use Spark.Dsl.Extension,
    sections: [@config_section, @functions_section],
    transformers: [
      EasyRpc.Transformers.GenerateRpcFunctions
    ],
    verifiers: [
      EasyRpc.Verifiers.ValidateConfig
    ]
end
