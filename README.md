[![Docs](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/easy_rpc)
[![Hex.pm](https://img.shields.io/hexpm/v/easy_rpc.svg?style=flat&color=blue)](https://hex.pm/packages/easy_rpc)

# EasyRpc

This library help developer easy to wrap a remote procedure call (rpc, library uses Erlang `:erpc` module) to local function.

EasyRpc supports some basic features for wrapping rpc: retry, timeout, error_handling.
Each function can has seperated options or use global options (in a module).

Can use EasyRpc with [ClusterHelper](https://hex.pm/packages/cluster_helper) for calling a rpc in a dynamic Elixir cluster.

## Installation

Adding `easy_rpc` library to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:easy_rpc, "~> 0.4.0"}
  ]
end
```

## Usage - defrpc way

In this way, you need to add config for node list & its select_mode.
The config can add in compile time or runtime or using {module, function arguments} for selecting by function.

For wrapping a remote function to local module you need to use macro `defrpc`.

### Add Configs

```Elixir
config :simple_example, :remote_defrpc,
  nodes: [:"remote@127.0.0.1"],  # or {ClusterHelper, :get_nodes, [:remote_api]},
  select_mode: :round_robin,
  sticky_node: true
```

Current version, `:round_robin` & `:sticky_node` are worked for process only.

### Declare functions

```Elixir
defmodule Remote
  use EasyRpc.DefRpc,
    otp_app: :simple_example,
    config_name: :remote_defrpc,
    # Remote module name
    module: RemoteNode.Interface,
    timeout: 1000

  defrpc :get_data
  defrpc :put_data, args: 1
  defrpc :clear, args: 2, as: :clear_data, private: true
  defrpc :put_data, args: [:name], new_name: :put_with_retry, retry: 3, timeout: 1000
end
```

## Usage - Config way

This is an example for declare by config in config.exs file.
All function & node info (excepted `nodes: {module, function, arguments}`) are generated at compile time.
For this way you need to work with config than module.

Follow steps

### Add config to config.exs

Put config to config.exs file, and use it in your module by using RpcWrapper.
User need separate config for each wrapper, and put it in config.exs

```Elixir
config :app_name, :wrapper_name,
  nodes: [:"test1@test.local"], # or using function like nodes: {Module, Fun, Args}
  error_handling: true,
  select_mode: :random,
  module: TargetApp.Interface.Api,
  functions: [
    # {function_name, arity, options}
    {:get_data, 1},
    {:put_data, 1, error_handling: false},
    {:clear, 2, new_name: :clear_data, retry: 3},
    {:clear_all, 0, new_name: :clear_all, private: true}, # wrap to private function.
  ]
```

### Wrap to local module

by using `use EasyRpc.RpcWrapper` in your module, you can call remote functions as local functions.

```Elixir
defmodule DataHelper do
  use EasyRpc.RpcWrapper,
    otp_app: :app_name,
    config_name: :account_wrapper

  def process_remote() do
    # call rpc like a local function.
    case get_data("key") do
      {:ok, data} ->
        # do something with data

      {:error, reason} ->
        # handle error
    end
  end
end

# Or call from other module like
{:ok, result} = DataHelper.get_data("my_key")
```

For more details please go to module's docs.

## Example

You can go to example folder to see how EasyRpc work, check config & run and see.

Go to [lib_examples on Github](https://github.com/ohhi-vn/lib_examples/tree/main/easy_rpc) and follow the README in sub folders.
