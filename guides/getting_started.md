# Getting Started with EasyRpc

This guide will walk you through the basics of using EasyRpc to wrap remote procedure calls as local functions.

## Prerequisites

- Elixir 1.15 or later
- A working Erlang distribution setup (for RPC calls between nodes)
- Basic understanding of Elixir modules and functions

## Installation

Add EasyRpc to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:easy_rpc, "~> 0.9.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Basic Usage

### Step 1: Define Your RPC Module

Create a module that uses EasyRpc and defines your RPC configuration:

```elixir
defmodule MyApp.RemoteApi do
  use EasyRpc

  config do
    # List of target nodes (static or dynamic)
    nodes [:"api@node1", :"api@node2"]
    
    # How to select which node to call
    select_mode :round_robin
    
    # Remote module to call on those nodes
    module RemoteNode.Api
    
    # Global timeout for all calls (in milliseconds)
    timeout 5_000
  end

  rpc_functions do
    # Wrap a remote function with 1 argument
    rpc_function :get_user, 1
    
    # Wrap a remote function with 2 arguments
    rpc_function :create_user, 2
    
    # You can also use argument names for better IDE support
    rpc_function :update_user, [:user_id, :attrs]
  end
end
```

### Step 2: Use the Generated Functions

EasyRpc will generate local functions that wrap the remote calls:

```elixir
# Call the remote function as if it were local
case MyApp.RemoteApi.get_user(123) do
  {:ok, user} ->
    # Success! Process the user
    process_user(user)
    
  {:error, %EasyRpc.Error{} = error} ->
    # Handle the error
    Logger.error("Failed to get user: #{EasyRpc.Error.format(error)}")
end
```

## Understanding Error Handling

EasyRpc supports two error handling modes:

### Mode 1: Raise on Error (Default)

```elixir
config do
  error_handling false  # This is the default
end

# This will raise if the RPC call fails
try do
  user = MyApp.RemoteApi.get_user(123)
rescue
  e in EasyRpc.Error ->
    Logger.error("RPC failed: #{EasyRpc.Error.format(e)}")
end
```

### Mode 2: Return Tagged Tuples

```elixir
config do
  error_handling true
end

# This returns {:ok, result} or {:error, error}
case MyApp.RemoteApi.get_user(123) do
  {:ok, user} -> process_user(user)
  {:error, error} -> handle_error(error)
end
```

## Node Selection Strategies

Choose how EasyRpc selects which node to call:

### Random (Default)

```elixir
config do
  select_mode :random
end
```

Each call randomly picks a node from the list.

### Round Robin

```elixir
config do
  select_mode :round_robin
end
```

Nodes are selected in order, cycling through the list. This is tracked per process.

### Hash-Based (Consistent)

```elixir
config do
  select_mode :hash
end
```

Same arguments always go to the same node (based on a hash of the arguments).

## Dynamic Node Discovery

Instead of a static node list, you can use a dynamic node provider:

```elixir
config do
  # MFA tuple: {Module, Function, Args}
  nodes_provider {ClusterHelper, :get_nodes, [:backend]}
  module RemoteNode.Api
end
```

The function should return a list of node names.

## Next Steps

- Check out the [ARCHITECTURE.md](ARCHITECTURE.html) for a deep dive into how EasyRpc works
- See the [README.md](../README.html) for complete DSL options
- Look at the [examples repository](https://github.com/ohhi-vn/lib_examples/tree/main/easy_rpc) for runnable examples
