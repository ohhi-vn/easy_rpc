[![Docs](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/easy_rpc)
[![Hex.pm](https://img.shields.io/hexpm/v/easy_rpc.svg?style=flat&color=blue)](https://hex.pm/packages/easy_rpc)

# EasyRpc

This library help developer easy to wrap a remote procedure call (rpc, library uses Erlang `:erpc` module).

## Installation

Adding `easy_rpc` library to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:easy_rpc, "~> 0.1.3"}
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
  error_handling: true,
  select_node_mode: :random,
  module: TargetApp.Interface.Api,
  functions: [
    # {function_name, arity, options}
    {:get_data, 1},
    {:put_data, 1, error_handling: false},
    {:clear, 2, new_name: :clear_data, retry: 3},
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
    # call rpc like a local function.
    case get_data("key") do
      {:ok, data} ->
        # do something with data

      {:error, reason} ->
        # handle error
    end
  end
end

# Or call from other module
{:ok, result} = DataHelper.get_data("my_key")
```

For details please go to module's docs.
