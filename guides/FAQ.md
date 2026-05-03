# Frequently Asked Questions (FAQ)

## General Questions

### What is EasyRpc?

EasyRpc is an Elixir library that makes it easy to wrap remote procedure calls (RPCs) as local functions. It uses Erlang's `:erpc` module under the hood and adds retry, timeout, and error-handling support.

### When should I use EasyRpc?

Use EasyRpc when you need to:
- Call functions on remote Erlang/Elixir nodes as if they were local
- Add retry and timeout logic to RPC calls
- Handle RPC errors gracefully
- Distribute calls across multiple nodes with different selection strategies

### What are the prerequisites?

- Elixir 1.15 or later
- A working Erlang distribution setup (nodes must be connected)
- Basic understanding of Elixir modules and functions

## Configuration

### What's the difference between `nodes` and `nodes_provider`?

- `nodes`: Static list of node names (e.g., `nodes [:"node1@host", :"node2@host"]`)
- `nodes_provider`: Dynamic node discovery via MFA tuple (e.g., `nodes_provider {MyModule, :get_nodes, []}`)

Use `nodes` for static clusters, `nodes_provider` when nodes come and go dynamically (e.g., with libcluster).

### What node selection strategy should I use?

- **`:random`** (default): Good for general use, spreads load randomly
- **`:round_robin`**: Distributes calls evenly, tracked per process
- **`:hash`**: Same arguments always go to the same node (useful for caching)

### What does `sticky_node` do?

When `sticky_node: true`, the first selected node is "pinned" for the lifetime of the process. Subsequent calls from the same process will use the same node (until the process dies or the node becomes unavailable).

## Error Handling

### What's the difference between error handling modes?

**Without error handling (default):**
```elixir
config do
  error_handling false
end

# Raises on error
user = MyApi.get_user(123)
```

**With error handling:**
```elixir
config do
  error_handling true
end

# Returns {:ok, result} or {:error, error}
case MyApi.get_user(123) do
  {:ok, user} -> ...
  {:error, error} -> ...
end
```

### When `error_handling` is enabled, does it affect all functions?

Yes, it's a global setting. However, you can override it per function:

```elixir
rpc_functions do
  rpc_function :get_user, 1, error_handling: false  # Override to raise
  rpc_function :create_user, 2  # Uses global setting
end
```

## Retry Logic

### How does retry work?

When `retry: N` is set, EasyRpc will retry the RPC call up to N times if it fails:

```elixir
config do
  retry 3
  sleep_before_retry 500  # Wait 500ms between retries
end
```

**Important:** When `retry > 0`, `error_handling` is automatically enabled for those calls.

### What's `sleep_before_retry`?

It adds a delay (in milliseconds) between retry attempts. This is useful for:
- Giving a flapping node time to recover
- Reducing pressure on a struggling service
- Implementing backoff strategies

## Performance

### Does EasyRpc add significant overhead?

EasyRpc adds minimal overhead:
- Node selection: O(1) for random, O(n) for round_robin (with caching)
- RPC execution: Same as `:erpc.call/4` plus small wrapper overhead
- Retry logic: Only activated on failure

### Should I use `:infinity` for timeout?

Be careful with `:infinity`. It means the call will wait forever. Use it only when:
- You're certain the remote node will respond
- The operation is truly unbounded
- You have other mechanisms to detect hangs

For most cases, set a reasonable timeout (e.g., 5000ms).

## Migration

### I'm using the old macro style. Should I migrate?

Yes! The old `use EasyRpc.RpcWrapper` style is deprecated. The new Spark DSL:
- Is more extensible
- Has better IDE support (with argument names)
- Supports private functions and aliases
- Will be the only supported style in future versions

See the [Migration Guide](migration_guide.html) for step-by-step instructions.

## Troubleshooting

### "No nodes available" error

This means:
1. The node list is empty, or
2. None of the specified nodes are available (not connected)

Check:
- Are the nodes connected? (use `Node.list/0`)
- Are the node names correct? (they must be atoms like `:"node@host"`)
- If using `nodes_provider`, does the function return a non-empty list?

### RPC calls hang or timeout

Possible causes:
1. Network issues between nodes
2. Remote function is taking too long
3. Node is overloaded

Solutions:
- Increase timeout: `timeout 30_000`
- Check node connectivity: `Node.ping(:"node@host")`
- Monitor remote node performance

### "Function not exported" error

The remote module doesn't export the function with the specified arity. Check:
- Is the module name correct in `config do...module...end`?
- Does the function exist with the right arity?
- Are you calling the right generated function name?

## Getting Help

- Check the [ARCHITECTURE.md](ARCHITECTURE.html) for deep technical details
- Visit the [examples repository](https://github.com/ohhi-vn/lib_examples/tree/main/easy_rpc)
- Open an issue on [GitHub](https://github.com/ohhi-vn/easy_rpc/issues)
- Join the discussion in the Elixir forums or Slack
