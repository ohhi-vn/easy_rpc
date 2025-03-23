[![Docs](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/easy_rpc)
[![Hex.pm](https://img.shields.io/hexpm/v/easy_rpc.svg?style=flat&color=blue)](https://hex.pm/packages/easy_rpc)

# EasyRpc

This library help developer easy to wrap a remote procedure call (rpc, library uses Erlang `:erpc` module).

EasyRpc supports some basic features for wrapping rpc: retry, timeout, error_handling.
Each function can has seperated options or use global options (config for all function in a module).

## Installation

Adding `easy_rpc` library to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:easy_rpc, "~> 0.2.1"}
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
