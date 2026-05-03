# Migration Guide: From Macro Style to Spark DSL

EasyRpc 0.9.0 introduced a new Spark DSL-based syntax that replaces the old macro-based approach. This guide will help you migrate your code.

## Overview of Changes

| Old Macro Style (0.7.x and earlier) | New Spark DSL Style (0.9.0+) |
|-------------------------------------|------------------------------|
| `use EasyRpc.RpcWrapper` | `use EasyRpc` |
| `config :my_app, :api, ...` | `config do ... end` |
| `defrpc :func, args: 1` | `rpc_function :func, 1` |
| `defrpc :func, args: [:a, :b]` | `rpc_function :func, [:a, :b]` |

## Step-by-Step Migration

### 1. Update Module Declaration

**Before:**
```elixir
defmodule MyApp.RemoteApi do
  use EasyRpc.RpcWrapper

  config :my_app, :remote_api,
    nodes: [:"node1@host"],
    module: RemoteModule
end
```

**After:**
```elixir
defmodule MyApp.RemoteApi do
  use EasyRpc

  config do
    nodes [:"node1@host"]
    module RemoteModule
  end
end
```

### 2. Update Configuration Syntax

**Before:**
```elixir
config :my_app, :remote_api,
  nodes: [:"node1@host", :"node2@host"],
  select_mode: :round_robin,
  sticky_node: true,
  module: RemoteModule,
  timeout: 5_000,
  retry: 3,
  error_handling: true
```

**After:**
```elixir
config do
  nodes [:"node1@host", :"node2@host"]
  select_mode :round_robin
  sticky_node true
  module RemoteModule
  timeout 5_000
  retry 3
  error_handling true
end
```

### 3. Update Function Definitions

**Before:**
```elixir
rpc_functions do
  defrpc :get_user, args: 1
  defrpc :create_user, args: 2, timeout: 10_000
  defrpc :delete_user, args: 1, new_name: :remove_user, private: true
end
```

**After:**
```elixir
rpc_functions do
  rpc_function :get_user, 1
  rpc_function :create_user, 2, timeout: 10_000
  rpc_function :delete_user, 1, new_name: :remove_user, private: true
end
```

### 4. Using Argument Names (New Feature!)

The new DSL supports argument names for better IDE support:

**New syntax:**
```elixir
rpc_functions do
  # Integer arity (old style, still works)
  rpc_function :get_user, 1
  
  # Argument names (new, better IDE support)
  rpc_function :get_user, [:user_id]
  rpc_function :create_user, [:user_id, :attrs]
end
```

## New Features in Spark DSL

### Private Functions

You can now generate private functions (`defp`):

```elixir
rpc_functions do
  rpc_function :internal_call, 1, private: true
  # This generates a defp, not def
end
```

### Function Aliases

Create functions with different names than the remote function:

```elixir
rpc_functions do
  rpc_function :remove_user, 1, new_name: :delete_user
  # Generates MyApp.RemoteApi.delete_user/1 that calls RemoteModule.remove_user/1
end
```

### Dynamic Node Discovery

New `nodes_provider` option:

```elixir
config do
  nodes_provider {MyCluster, :get_nodes, [:backend]}
  module RemoteModule
end
```

## Compatibility

The old macro style (`use EasyRpc.RpcWrapper`) is deprecated but still works in 0.9.0. However, it will be removed in a future version. We recommend migrating to the new Spark DSL as soon as possible.

## Common Issues

### Issue: "undefined function defrpc/2"

**Solution:** You're using the old syntax. Update to `rpc_function` within a `rpc_functions do...end` block.

### Issue: Configuration not being applied

**Solution:** Make sure you're using the `config do...end` block syntax, not the old `config :app, :key, ...` syntax.

### Issue: "unknown option :args"

**Solution:** The new DSL uses `rpc_function :name, arity` or `rpc_function :name, [:arg1, :arg2]` instead of `defrpc :name, args: arity`.

## Need Help?

- Check the [ARCHITECTURE.md](ARCHITECTURE.html) for detailed documentation
- Look at the [README.md](../README.html) for current syntax
- Visit the [examples repository](https://github.com/ohhi-vn/lib_examples/tree/main/easy_rpc)
- Open an issue on [GitHub](https://github.com/ohhi-vn/easy_rpc/issues)
