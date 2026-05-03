[![Docs](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/easy_rpc)
[![Hex.pm](https://img.shields.io/hexpm/v/easy_rpc.svg?style=flat&color=blue)](https://hex.pm/packages/easy_rpc)

# EasyRpc

A library that makes it easy to wrap a remote procedure call (RPC) as a local function.
EasyRpc uses Erlang's `:erpc` module under the hood and adds retry, timeout, and error-handling support on top.

Each function can carry its own options, or inherit global options declared at the module level.
EasyRpc works seamlessly with [ClusterHelper](https://hex.pm/packages/cluster_helper) for dynamic Elixir clusters.

*Note: Collaboration between human & AI.*

## Installation

Add `easy_rpc` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:easy_rpc, "~> 0.9.0"}
  ]
end
```

---

## Usage (Spark DSL)

EasyRpc now uses [Spark DSL](https://hexdocs.pm/spark) for a more powerful and extensible DSL experience.

### 1. Define your RPC module

```elixir
defmodule MyApp.RemoteApi do
  use EasyRpc

  config do
    nodes [:"api@node1", :"api@node2"]
    select_mode :round_robin
    sticky_node true
    module RemoteNode.Api
    timeout 5_000
    retry 0
    error_handling false
  end

  rpc_functions do
    rpc_function :get_user, 1
    rpc_function :create_user, 2, retry: 3, timeout: 10_000
    rpc_function :delete_user, 1, new_name: :remove_user, private: true
  end
end
```

### 2. Use the generated functions

```elixir
# With error handling disabled (raises on error)
user = MyApp.RemoteApi.get_user(123)

# With error handling enabled (returns {:ok, result} or {:error, reason})
case MyApp.RemoteApi.get_user(123) do
  {:ok, user} -> process_user(user)
  {:error, %EasyRpc.Error{} = error} -> Logger.error(EasyRpc.Error.format(error))
end

# Private functions (marked with private: true) are not exposed in the public API
# They can only be called from within the module itself
```

### DSL Options

#### `config` section:

| Option                | Description                                           |
|-----------------------|-------------------------------------------------------|
| `:nodes`             | Static list of node names (e.g., [:"node1@host"]) |
| `:nodes_provider`    | Dynamic node discovery via MFA `{Mod, Fun, Args}`    |
| `:select_mode`       | `:random`, `:round_robin`, or `:hash` (default: `:random`) |
| `:sticky_node`       | Pin to first selected node (default: `false`)     |
| `:module`            | Remote module to call (required)                  |
| `:timeout`           | Global timeout in ms (default: 5000, use `:infinity` for no timeout) |
| `:retry`             | Global retry count (default: 0)                    |
| `:sleep_before_retry`| Ms to wait before retry (default: 0)              |
| `:error_handling`    | Return {:ok, result} tuples (default: `false`)    |
| `:enable_logging`    | Enable detailed logging (default: `true`)         |

#### `rpc_function` options:

| Option                | Description                                           |
|-----------------------|-------------------------------------------------------|
| `:new_name`          | Override the generated function name                  |
| `:private`           | Generate as `defp` (default: `false`)                 |
| `:retry`             | Override global retry count                           |
| `:timeout`           | Override global timeout (ms)                         |
| `:sleep_before_retry`| Override global sleep before retry                 |
| `:error_handling`    | Override global error-handling flag                   |

---

## Node Selection Strategies

Configure via the `select_mode:` option in your `config` section:

| Strategy       | Description                                                     |
|----------------|-----------------------------------------------------------------|
| `:random`      | Randomly picks a node on each call (default)                    |
| `:round_robin` | Circular distribution, tracked per process                      |
| `:hash`        | Consistent hashing on args — same args always hit the same node |

### Sticky Nodes

```elixir
config do
  nodes: [:"node1@host", :"node2@host"]
  select_mode: :random
  sticky_node: true
  module: RemoteNode.Api
end
```
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
config do
  error_handling true
end

# or per rpc_function:
rpc_functions do
  rpc_function :get_user, 1, error_handling: true
end
```

---

## Retry Logic

```elixir
# Global retry
config do
  retry 3
end

# Per-function
rpc_functions do
  rpc_function :critical_op, 1, retry: 5
end
```

> When `retry > 0`, `error_handling` is automatically enabled — retried calls
> always return `{:ok, result} | {:error, %EasyRpc.Error{}}`.

---

## Sleep Before Retry

By default EasyRpc retries immediately after a failure. Use `sleep_before_retry`
to add a fixed delay (in milliseconds) between attempts. This is useful for
giving a remote node time to recover, or for reducing thundering-herd pressure
on a flapping service.

```elixir
# Global — all retries in this config wait 500 ms
config do
  retry 3
  sleep_before_retry 500
end

# Per-function override
rpc_functions do
  rpc_function :critical_op, 1, retry: 5, sleep_before_retry: 200
end
```

The sleep happens **between** attempts — there is no delay before the first
call, and no delay after the final failure.

```
attempt 1 → fails → sleep 500 ms
attempt 2 → fails → sleep 500 ms
attempt 3 → fails → sleep 500 ms
attempt 4 → fails → return {:error, ...}
```

> `sleep_before_retry` requires a non-negative integer. The default is `0`
> (no sleep). Setting it without also setting `retry` has no effect.

---

## Timeout Configuration

```elixir
# Global
config do
  timeout 5_000
end

# Per-function
rpc_functions do
  rpc_function :long_op, 1, timeout: 30_000
  rpc_function :health_check, 0, timeout: 500
  rpc_function :no_limit, 0, timeout: :infinity
end
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
