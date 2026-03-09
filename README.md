[![Docs](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/easy_rpc)
[![Hex.pm](https://img.shields.io/hexpm/v/easy_rpc.svg?style=flat&color=blue)](https://hex.pm/packages/easy_rpc)

# EasyRpc

A library that makes it easy to wrap a remote procedure call (RPC) as a local function.
EasyRpc uses Erlang's `:erpc` module under the hood and adds retry, timeout, and error-handling support on top.

Each function can carry its own options, or inherit global options declared at the module level.
EasyRpc works seamlessly with [ClusterHelper](https://hex.pm/packages/cluster_helper) for dynamic Elixir clusters.

*Note: Collab between human & AI.*

## Installation

Add `easy_rpc` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:easy_rpc, "~> 0.7.0"}
  ]
end
```

---

## Two Usage Approaches

| | `DefRpc` | `RpcWrapper` |
|---|---|---|
| Functions declared | In module via `defrpc` macro | In config file |
| Node config loaded | At **runtime** per call | At **compile time** |
| Cluster topology changes | ✅ Picked up automatically | Requires recompile |
| Best for | Explicit control, dynamic clusters | All-in-config, stable topology |

---

## Usage — `DefRpc` (declarative macros)

### 1. Add node config

```elixir
# config/config.exs  (or runtime.exs for runtime topology)
config :my_app, :remote_defrpc,
  nodes: [:"remote@127.0.0.1"],
  # or: nodes: {ClusterHelper, :get_nodes, [:remote_api]},
  select_mode: :round_robin,
  sticky_node: true
```

> `:round_robin` and `:sticky_node` are tracked **per process**.

### 2. Declare functions

```elixir
defmodule MyApp.Remote do
  use EasyRpc.DefRpc,
    otp_app: :my_app,
    config_name: :remote_defrpc,
    module: RemoteNode.Interface,
    timeout: 1_000

  defrpc :get_data
  defrpc :put_data, args: 1
  defrpc :clear, args: 2, as: :clear_data, private: true
  defrpc :put_data, args: [:name], as: :put_with_retry, retry: 3, timeout: 1_000
end
```

**`defrpc` options:**

| Option              | Description                                           |
|---------------------|-------------------------------------------------------|
| `:args`             | Arity as integer, `[]` (zero), or list of named atoms |
| `:as` / `:new_name` | Override the generated function name                  |
| `:private`          | Generate as `defp` (default: `false`)                 |
| `:retry`            | Override global retry count                           |
| `:timeout`          | Override global timeout (ms or `:infinity`)           |
| `:error_handling`   | Override global error-handling flag                   |

---

## Usage — `RpcWrapper` (config-driven)

All function and node information is declared in config.
Functions are generated at compile time.

### 1. Add config

```elixir
# config/config.exs
config :my_app, :data_wrapper,
  nodes: [:"node1@host", :"node2@host"],
  # or: nodes: {ClusterHelper, :get_nodes, [:data]},
  error_handling: true,
  select_mode: :random,
  module: TargetApp.Interface.Api,
  functions: [
    # {function_name, arity}
    # {function_name, arity, options}
    {:get_data, 1},
    {:put_data, 1, [error_handling: false]},
    {:clear, 2, [new_name: :clear_data, retry: 3]},
    {:clear_all, 0, [new_name: :reset, private: true]}
  ]
```

### 2. Use in your module

```elixir
defmodule MyApp.DataHelper do
  use EasyRpc.RpcWrapper,
    otp_app: :my_app,
    config_name: :data_wrapper

  def process_remote() do
    case get_data("key") do
      {:ok, data}     -> data
      {:error, reason} -> {:error, reason}
    end
  end
end

# Or call directly:
{:ok, result} = MyApp.DataHelper.get_data("my_key")
```

---

## Node Selection Strategies

Configure via `select_mode:` in your config:

| Strategy       | Description                                                     |
|----------------|-----------------------------------------------------------------|
| `:random`      | Randomly picks a node on each call (default)                    |
| `:round_robin` | Circular distribution, tracked per process                      |
| `:hash`        | Consistent hashing on args — same args always hit the same node |

### Sticky Nodes

```elixir
config :my_app, :api,
  nodes: [:node1@host, :node2@host],
  select_mode: :random,
  sticky_node: true   # process pins to first selected node
```

### Dynamic Node Discovery

```elixir
config :my_app, :api,
  nodes: {ClusterHelper, :get_nodes, [:backend]},
  select_mode: :round_robin
```

---

## Error Handling

### Without error handling (default — raises on error)

```elixir
user = MyApi.get_user(123)
```

### With error handling (returns tagged tuples)

```elixir
case MyApi.get_user(123) do
  {:ok, user}                    -> process(user)
  {:error, %EasyRpc.Error{} = e} -> Logger.error(EasyRpc.Error.format(e))
end
```

Enable globally in config or per function:

```elixir
config :my_app, :api, error_handling: true

# or per defrpc:
defrpc :get_user, args: 1, error_handling: true
```

---

## Retry Logic

```elixir
# Global retry
config :my_app, :api, retry: 3

# Per-function
defrpc :critical_op, args: 1, retry: 5
```

> When `retry > 0`, `error_handling` is automatically enabled — retried calls
> always return `{:ok, result} | {:error, %EasyRpc.Error{}}`.

---

## Timeout Configuration

```elixir
# Global
config :my_app, :api, timeout: 5_000

# Per-function
defrpc :long_op,    args: 1, timeout: 30_000
defrpc :health_check,        timeout: 500
defrpc :no_limit,            timeout: :infinity
```

---

## Examples

See the [lib_examples repository](https://github.com/ohhi-vn/lib_examples/tree/main/easy_rpc) for complete, runnable examples.

---

## AI Agents & MCP Support

Sync usage rules from deps into your repo for AI agent support:

```bash
mix usage_rules.sync AGENTS.md --all \
  --link-to-folder deps \
  --inline usage_rules:all
```

Start the MCP server:

```bash
mix tidewave
```

Configure your agent to connect to `http://localhost:4113/tidewave/mcp` (change port in `mix.exs` if needed).
See [Tidewave docs](https://hexdocs.pm/tidewave/) for details.
