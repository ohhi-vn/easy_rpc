[![Docs](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/easy_rpc)
[![Hex.pm](https://img.shields.io/hexpm/v/easy_rpc.svg?style=flat&color=blue)](https://hex.pm/packages/easy_rpc)

# EasyRpc

This library help developer easy to wrap a remote procedure call (rpc, library uses Erlang `:erpc` module).

## Installation

Adding `easy_rpc` library to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:easy_rpc, "~> 0.1.1"}
  ]
end
```

## Usage

Follow steps

### Add config to config.exs

Put config to config.exs file, and use it in your module by using RpcWrapper.
User need separate config for each wrapper, and put it in config.exs

```Elixir
config :app_name, :wrapper_name,
  nodes: [:"test1@test.local"],
  # or nodes: {MyModule, :get_nodes, []}
  error_handling: true, # enable error handling, global setting for all functions.
  select_node_mode: :random, # select node mode, global setting for all functions.
  module: TargetApp.Interface.Api,
  functions: [
    # {function_name, arity}
    {:get_data, 1},
    {:put_data, 1},
    # {function_name, arity, opts}
    {:clear, 2, [new_name: :clear_data, retry: 3, error_handling: false]},
  ]
```

### Add to local module

by using `use EasyRpc.RpcWrapper` in your module, you can call remote functions as local functions.

```Elixir
defmodule DataHelper do
use EasyRpc.RpcWrapper,
  otp_app: :app_name,
  config_name: :account_wrapper

def process_remote() do
  case get_data("key") do
    {:ok, data} ->
      # do something with data
    {:error, reason} ->
      # handle error
  end
end
```

For details please go to module's docs.
