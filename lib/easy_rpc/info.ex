defmodule EasyRpc.Info do
  @moduledoc """
  Info module for introspecting EasyRpc DSL definitions.

  Provides functions to query the DSL state of modules using EasyRpc.

  ## Examples

      # Get all RPC functions
      EasyRpc.Info.rpc_functions(MyApp.RemoteApi)

      # Get config values
      EasyRpc.Info.config(MyApp.RemoteApi)
  """

  use Spark.InfoGenerator,
    extension: EasyRpc.Dsl,
    sections: [:config, :rpc_functions]
end
