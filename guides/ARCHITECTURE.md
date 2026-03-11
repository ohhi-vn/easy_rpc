# EasyRpc Architecture Documentation

**Version:** 0.8.0
**Last Updated:** 2025

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Module Hierarchy](#module-hierarchy)
4. [Core Components](#core-components)
5. [Data Flow](#data-flow)
6. [Design Patterns](#design-patterns)
7. [Extension Points](#extension-points)

---

## Overview

EasyRpc is a modular, well-structured library for wrapping remote procedure calls in Elixir. The architecture follows SOLID principles with clear separation of concerns, defined behaviors, and comprehensive error handling.

### Key Architectural Principles

- **Modularity**: Each component has a single, well-defined responsibility
- **Extensibility**: Behavior-based design allows custom implementations
- **Consistency**: Unified error handling and logging across all components
- **Type Safety**: Complete typespec coverage with Dialyzer validation
- **Backward Compatibility**: Legacy shims while introducing modern patterns

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         EasyRpc Library                              │
│                      (Public API & Docs)                             │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                ┌────────────────┴────────────────┐
                │                                 │
        ┌───────▼────────┐              ┌────────▼────────┐
        │  RpcWrapper    │              │    DefRpc       │
        │  (Config-based)│              │  (Declarative)  │
        └───────┬────────┘              └────────┬────────┘
                │                                 │
                └────────────────┬────────────────┘
                                 │
                        ┌────────▼────────┐
                        │ FunctionGenerator│
                        │   (Utilities)    │
                        └────────┬────────┘
                                 │
                ┌────────────────┴────────────────┐
                │                                 │
        ┌───────▼────────┐              ┌────────▼────────┐
        │ WrapperConfig  │              │  NodeSelector   │
        │ (Configuration)│              │   (Strategy)    │
        └───────┬────────┘              └────────┬────────┘
                │                                 │
                └────────────────┬────────────────┘
                                 │
                        ┌────────▼────────┐
                        │    RpcCall      │
                        │   (Executor)    │
                        └────────┬────────┘
                                 │
                ┌────────────────┴────────────────┐
                │                                 │
        ┌───────▼────────┐              ┌────────▼────────┐
        │ RpcExecutor    │              │     Error       │
        │  (Behavior)    │              │   (Unified)     │
        └────────────────┘              └─────────────────┘
                                                 │
                                        ┌────────┴────────┐
                                        │                 │
                                ┌───────▼──────┐  ┌──────▼────────┐
                                │ConfigError   │  │   RpcError    │
                                │(Compat shim) │  │ (Compat shim) │
                                └──────────────┘  └───────────────┘
```

---

## Module Hierarchy

### Layer 1: Public API

```
EasyRpc
├── Documentation & Examples
├── Version Information
└── Public Interface
```

### Layer 2: Wrapper Implementations

```
RpcWrapper (Config-based)          DefRpc (Declarative)
├── Macro: __using__/1            ├── Macro: __using__/1
├── Function Generation           ├── Macro: defrpc/2
└── Compile-time Config Loading   └── Runtime Node Config Loading
```

### Layer 3: Utilities & Shared Logic

```
FunctionGenerator                  WrapperConfig               NodeSelector
├── normalize_function_info/1     ├── load_config!/2          ├── new/4
├── resolve_function_name/2       ├── load_from_options!/1    ├── select_node/2
├── merge_config/2                ├── new!/2-6                ├── Strategy: random
├── parse_arity/1                 ├── validate!/1             ├── Strategy: round_robin
├── generate_arg_vars/1           └── Type Specs              ├── Strategy: hash
└── validate_function_opts!/1                                 └── Sticky Node Support
```

### Layer 4: Core Execution

```
RpcCall (implements RpcExecutor)
├── execute/3              ← primary API
├── execute_with_retry/3   ← primary API
├── execute_dynamic/4      ← primary API (DefRpc path)
├── rpc_call/2             ← backward-compat alias
├── rpc_call_dynamic/3     ← backward-compat alias
├── Error Handling
├── Retry Logic (with optional sleep between attempts)
└── Structured Logging
```

### Layer 5: Cross-Cutting Concerns

```
Error (Unified)                   RpcExecutor (Behavior)
├── Type: config_error           ├── Callback: execute/3
├── Type: rpc_error              ├── Callback: execute_with_retry/3
├── Type: node_error             └── Callback: validate_config/1 (optional)
├── Type: timeout_error
├── Type: validation_error
├── wrap_exception/2
├── format/1
└── log/2
```

---

## Core Components

### 1. EasyRpc (Main Module)

**Purpose:** Public API and comprehensive documentation

**Responsibilities:**

- Library overview and usage guide
- API documentation
- Version management
- Entry point for users

**Key Functions:**

- `version/0` - Returns library version

---

### 2. RpcWrapper (Config-Based Approach)

**Purpose:** Generate wrapper functions from configuration at compile time

**Responsibilities:**

- Read function definitions from application config
- Generate wrapper functions via `FunctionGenerator`
- Apply global configuration to all functions

**Usage Pattern:**

```elixir
defmodule MyApi do
  use EasyRpc.RpcWrapper,
    otp_app: :my_app,
    config_name: :api_config
end
```

**Architecture:**

```
Application Config → WrapperConfig.load_config!/2 → WrapperConfig
                                                          ↓
Function List → FunctionGenerator helpers → Generated def/defp
                                                          ↓
Runtime Call → RpcCall.execute/3 → Remote Result
```

> Node config is resolved at **compile time**. For runtime node changes, use
> the `DefRpc` approach instead.

---

### 3. DefRpc (Declarative Approach)

**Purpose:** Explicitly declare each wrapped function using the `defrpc` macro

**Responsibilities:**

- Provide `defrpc` macro for per-function declaration
- Support per-function configuration overrides
- Load node config **dynamically at runtime** on every call

**Usage Pattern:**

```elixir
defmodule MyApi do
  use EasyRpc.DefRpc,
    otp_app: :my_app,
    config_name: :nodes_config,
    module: RemoteModule

  defrpc :get_user, args: 1
  defrpc :create_user, args: 2, retry: 3, sleep_before_retry: 200
end
```

**Architecture:**

```
defrpc Macro → FunctionGenerator helpers → Generated def/defp
                                                  ↓
Runtime Call → NodeSelector.load_config!/2 (each call)
                                                  ↓
             → RpcCall.execute_dynamic/4 → Remote Result
```

> Because node config is reloaded on every call, `DefRpc` handles topology
> changes (e.g. new nodes joining a cluster) without recompiling.

---

### 4. FunctionGenerator (Utility Module)

**Purpose:** Extract common compile-time function generation logic shared by
`RpcWrapper` and `DefRpc`

**Responsibilities:**

- Normalize function specifications into canonical `{name, arity, opts}` tuples
- Merge global and per-function `WrapperConfig` values, including `sleep_before_retry`
- Parse arity specifications (integer, `[]`, or named-atom list)
- Generate AST variable lists for macro-expanded `def` bodies
- Validate per-function option keys and values

**Key Functions:**

- `normalize_function_info/1` - Standardise function specs
- `resolve_function_name/2` - Handle `:as` / `:new_name` overrides
- `merge_config/2` - Combine global and local configs; auto-enables
  `error_handling` when `retry > 0`; propagates `sleep_before_retry`
- `parse_arity/1` - Handle integer, empty list, and atom-list arities
- `generate_arg_vars/1` - Create argument variable AST nodes
- `validate_function_opts!/1` - Reject unknown or badly-typed options

**Benefits:**

- Single implementation shared by both wrapper approaches (DRY)
- Consistent behaviour and error messages in both
- Easily unit-tested in isolation

---

### 5. WrapperConfig (Configuration Management)

**Purpose:** Validate and manage RPC configuration

**Responsibilities:**

- Load configuration from application env, keyword list, or direct creation
- Validate all configuration parameters, raising `EasyRpc.Error` on failure
- Provide a type-safe config struct consumed by `RpcCall`
- Define function spec validation rules

**Configuration Sources:**

1. `load_config!/2` — Application environment
2. `load_from_options!/1` — Keyword list
3. `new!/2-6` — Direct struct creation

**Fields:**

| Field                 | Type                          | Default   | Description                                      |
|-----------------------|-------------------------------|-----------|--------------------------------------------------|
| `node_selector`       | `%NodeSelector{}` or `nil`    | —         | Node selection strategy                          |
| `module`              | `atom`                        | required  | Remote module to call                            |
| `timeout`             | `pos_integer \| :infinity`    | `5_000`   | Per-call timeout in milliseconds                 |
| `retry`               | `non_neg_integer`             | `0`       | Number of retry attempts on failure              |
| `sleep_before_retry`  | `non_neg_integer`             | `0`       | Milliseconds to sleep between retry attempts     |
| `error_handling`      | `boolean`                     | `false`   | Return tagged tuples instead of raising          |
| `functions`           | `[function_spec]`             | `[]`      | Function list for `RpcWrapper`                   |

**Validation Rules:**

- `module`: non-nil atom
- `timeout`: positive integer or `:infinity`
- `retry`: non-negative integer
- `sleep_before_retry`: non-negative integer
- `error_handling`: boolean
- `node_selector`: `%NodeSelector{}` or `nil`
- `functions`: list of valid `{name, arity}` or `{name, arity, keyword}` specs

---

### 6. NodeSelector (Selection Strategy)

**Purpose:** Select target nodes for RPC calls

**Responsibilities:**

- Implement node selection strategies
- Manage per-process sticky node and round-robin state
- Support dynamic node discovery via MFA
- Validate node configuration

**Strategies:**

#### Random Selection

```
[node1, node2, node3] → Enum.random() → node2
```

#### Round Robin (Per Process)

```
Process 1: node1 → node2 → node3 → node1 ...
Process 2: node2 → node3 → node1 → node2 ...
```

#### Hash-Based (Consistent)

```
:erlang.phash2(args, num_nodes) → node_index
["user123"] → hash → 2 → node3  (always the same for same args)
```

#### Sticky Node (Per Process)

```
First call  → selects node1, stores in process dictionary
Subsequent  → always returns node1 for that process
```

**State Management:**

- Per-process state via process dictionary
- Keys: `{:easy_rpc, :sticky_node, id}`, `{:easy_rpc, :round_robin, id}`
- Isolated per selector ID — multiple selectors never collide

---

### 7. RpcCall (Executor)

**Purpose:** Execute remote procedure calls

**Responsibilities:**

- Implement `RpcExecutor` behavior
- Execute RPC with or without error handling
- Implement retry logic with configurable sleep between attempts
- Safely handle node-selection failures inside the error-handling path
- Manage timeouts via `:erpc`
- Provide structured, detail-rich logging

**Primary API:**

- `execute/3` — respects `config.error_handling` and `config.retry`
- `execute_with_retry/3` — always uses error handling
- `execute_dynamic/4` — resolves `NodeSelector` at call time (used by `DefRpc`)

**Backward-Compat Aliases (do not use in new code):**

- `rpc_call/2` → `execute/3`
- `rpc_call_dynamic/3` → `execute_dynamic/4`

**Execution Modes:**

```elixir
# Bare (error_handling: false, retry: 0)
execute(config, :get_user, [123])
#=> %User{id: 123}  # raises on any error

# With error handling
execute(config, :get_user, [123])
#=> {:ok, %User{id: 123}}
#=> {:error, %EasyRpc.Error{...}}

# With retry and sleep (automatically enables error handling)
execute_with_retry(config, :get_user, [123])
# retries up to config.retry times, sleeping config.sleep_before_retry ms between each
#=> {:ok, result} | {:error, error}
```

**Call Flow:**

```
execute/3
    │
    ├─ error_handling or retry > 0?
    │       │
    │    Yes │                           No
    │        ▼                           ▼
    │  execute_with_error_handling    execute_bare
    │        │                           │
    │   select_node_safe            select_node
    │        │                           │
    │   {:ok, node} or {:error, _}   node (raises on failure)
    │        │
    └────────┴───────────────────────────┘
                        │
             :erpc.call(node, mod, fun, args, timeout)
                        │
             ┌──────────┴──────────┐
           Success               Exception / throw
             │                        │
         log_success            Error.wrap_exception
             │                        │
         return result          should_retry?
                                  │         │
                                 Yes        No
                                  │         │
                             log_retry  log_failure
                                  │         │
                        maybe_sleep(sleep_before_retry)
                                  │
                            execute again  {:error, error}
```

**Node Selection Safety:**

Node selection runs through `select_node_safe/2`, which wraps
`NodeSelector.select_node/2` in a `rescue` and returns
`{:ok, node} | {:error, %EasyRpc.Error{}}`. This ensures that a missing
or empty node list never crashes the calling process when `error_handling`
is enabled — the failure enters the normal `handle_error/6` path, respecting
retry and logging just like any RPC error. In bare mode (`error_handling: false`),
node selection errors are logged then re-raised.

---

### 8. Error (Unified Error Handling)

**Purpose:** Provide consistent, structured error handling across the library

**Responsibilities:**
- Define error types and the `%EasyRpc.Error{}` struct
- Wrap raw exceptions with contextual metadata
- Format error messages for logging and display
- Log errors at configurable levels

**Error Structure:**

```elixir
%EasyRpc.Error{
  type: :rpc_error,
  message: "boom from rpc",
  details: [
    node: :remote@host,
    attempt: 2,
    module: MyModule,
    function: :get_user,
    exception: RuntimeError   # struct name of the original exception
  ]
}
```

**Error Types:**

- `:config_error` — Configuration validation failures
- `:rpc_error` — Remote call failures (default for unknown exceptions)
- `:node_error` — Node connection/selection issues
- `:timeout_error` — Call timeout (classified by exception module name)
- `:validation_error` — Input validation failures

**Format Output:**

```
[config_error] Invalid timeout
[rpc_error] Connection refused | details: [node: :n1@host, attempt: 1]
```

**Exception Classification** (via `wrap_exception/2`):

- Module name contains `"timeout"` → `:timeout_error`
- Module name contains `"nodedown"` or `"noconnection"` → `:node_error`
- All others → `:rpc_error`

---

### 9. ConfigError / RpcError (Backward-Compat Shims)

**Purpose:** Maintain API compatibility with code written against older versions

These modules delegate entirely to `EasyRpc.Error`. New code should use
`EasyRpc.Error` directly.

---

### 10. RpcExecutor (Behavior)

**Purpose:** Define the contract for RPC execution implementations

**Callbacks:**

```elixir
@callback execute(config, function, args) :: result | raw_result
@callback execute_with_retry(config, function, args) :: result

# Optional — pre-execution config validation hook
@callback validate_config(config) :: :ok | {:error, term}
```

**Benefits:**

- Clear interface definition
- Enables testing with mock implementations
- Allows alternative executor implementations

---

## Data Flow

### Complete Request Flow

```
1. User Code
   MyApi.get_user(123)
        ↓
2. Generated Wrapper Function
   - Holds compiled WrapperConfig (RpcWrapper)
   - OR loads node config at call time (DefRpc → execute_dynamic)
        ↓
3. RpcCall.execute/3 (or execute_dynamic/4)
   - Selects node safely via select_node_safe/2
   - Logs call with module, function/arity, node, timeout, retry, sleep_before_retry
        ↓
4. :erpc.call/5
   - Network call to remote node
   - Executes RemoteModule.get_user(123) on that node
        ↓
5. Response Handling
   - Success → log_success → return result
   - Exception → Error.wrap_exception → retry?
       → yes: log_retry → sleep sleep_before_retry ms → retry
       → no:  log_failure → return {:error, error}
        ↓
6. Return to Caller
   - Bare result (error_handling: false)
   - {:ok, result} | {:error, %EasyRpc.Error{}} (error_handling: true)
```

### Configuration Loading Flow

```
Application.get_env(:my_app, :config_name)
        ↓
WrapperConfig.load_config!/2
        ↓
Validate all parameters (raises EasyRpc.Error on failure)
  — includes sleep_before_retry: non-negative integer
        ↓
NodeSelector.load_config!/2 (same config key)
        ↓
Validate node configuration
        ↓
Return %WrapperConfig{node_selector: %NodeSelector{}, sleep_before_retry: N, ...}
```

### Error Handling Flow

```
Remote Call Fails (or node selection fails)
        ↓
Exception / throw raised inside :erpc.call
(or {:error, _} returned by select_node_safe/2)
        ↓
RpcCall catches with rescue / catch
        ↓
Error.wrap_exception/2  (or Error.rpc_error/2 for catches)
  — sets type, message, details: [node, attempt, module, function, exception]
        ↓
should_retry?(config, attempt)?
        ↓
  Yes → log_retry (warning)
      → Process.sleep(config.sleep_before_retry)   # 0 ms = no-op
      → execute_with_error_handling(attempt + 1)
  No  → log_failure (error, "failed permanently after N attempt(s)")
      → {:error, %EasyRpc.Error{}}
```

---

## Design Patterns

### 1. Behavior Pattern

- **Module:** `RpcExecutor`
- **Purpose:** Define clear execution contracts
- **Benefit:** Testability and extensibility

### 2. Strategy Pattern

- **Module:** `NodeSelector`
- **Purpose:** Pluggable node selection strategies
- **Strategies:** Random, Round Robin, Hash, Sticky

### 3. Template Method Pattern

- **Module:** `RpcCall`
- **Purpose:** Common execution flow with customizable error / retry / sleep handling
- **Variants:** Bare, with error handling, with retry, dynamic

### 4. Facade Pattern

- **Modules:** `EasyRpc`, `RpcWrapper`, `DefRpc`
- **Purpose:** Simple interface to a complex subsystem
- **Benefit:** Easy to use, complexity hidden

### 5. Adapter Pattern

- **Modules:** `ConfigError`, `RpcError`
- **Purpose:** Backward compatibility while delegating to `Error`
- **Benefit:** Smooth migration path for existing callers

### 6. Builder Pattern

- **Module:** `WrapperConfig`
- **Purpose:** Flexible, validated configuration construction
- **Methods:** `new!/2-6`, `load_config!/2`, `load_from_options!/1`

---

## Extension Points

### 1. Custom RPC Executor

Implement the `RpcExecutor` behavior:

```elixir
defmodule MyCustomExecutor do
  @behaviour EasyRpc.Behaviours.RpcExecutor

  @impl true
  def execute(config, function, args) do
    # Custom implementation — e.g. add connection pooling, metrics, tracing
  end

  @impl true
  def execute_with_retry(config, function, args) do
    # Custom retry logic — e.g. exponential backoff instead of fixed sleep
  end
end
```

### 2. Telemetry Integration

```elixir
defmodule MyInstrumentedExecutor do
  @behaviour EasyRpc.Behaviours.RpcExecutor

  @impl true
  def execute(config, function, args) do
    start = System.monotonic_time()
    result = EasyRpc.RpcCall.execute(config, function, args)
    duration = System.monotonic_time() - start

    :telemetry.execute(
      [:my_app, :rpc, :call],
      %{duration: duration},
      %{node: config.node_selector, function: function, success: match?({:ok, _}, result)}
    )

    result
  end
end
```

### 3. Dynamic Node Discovery

Use MFA tuples for runtime node resolution:

```elixir
config :my_app, :api,
  nodes: {ClusterHelper, :get_nodes, [:api_cluster]},
  select_mode: :round_robin
```

### 4. Custom Error Enrichment

```elixir
defmodule MyApp.RpcErrors do
  def enrich(%EasyRpc.Error{} = err, context) do
    updated_details = Keyword.merge(err.details || [], context)
    %{err | details: updated_details}
  end
end
```

---

## Component Relationships

### Dependency Graph

```
EasyRpc (public API)
    ↓
RpcWrapper, DefRpc (wrapper macros)
    ↓
FunctionGenerator (compile-time utilities)
    ↓
WrapperConfig, NodeSelector (config & strategy)
    ↓
RpcCall (executor — implements RpcExecutor)
    ↓
RpcExecutor (behavior), Error (cross-cutting)
    ↓
ConfigError, RpcError (backward-compat shims → Error)
```

### Compile-Time vs Runtime

**Compile-Time:**

- Function generation via macros (`RpcWrapper`, `DefRpc`)
- `WrapperConfig` loading and validation (`RpcWrapper`)
- Typespec and Dialyzer checking

**Runtime:**

- Node selection (`NodeSelector`) via `select_node_safe/2`
- Node config loading (`DefRpc` via `execute_dynamic`)
- RPC execution (`:erpc.call`)
- Error handling, wrapping, and logging
- Retry logic with optional sleep between attempts
- Retry logic

---

## Performance Considerations

### Memory Footprint

- Minimal: mostly compiled function definitions
- Per-process dictionary entries for sticky / round-robin state
- No global state or ETS tables required

### Execution Overhead

- Wrapper function call: ~0.1 µs (macro-generated)
- Node selection: ~1–5 µs (random / hash) | ~10 µs (MFA call)
- Dynamic config reload (`DefRpc`): ~10–50 µs (`Application.get_env`)
- RPC call: network latency (typically 1–50 ms on LAN)
- Error handling path: ~10–50 µs additional overhead
- `sleep_before_retry`: adds exactly `N ms × retry_count` to the worst-case
  latency of a fully-exhausted retry sequence; zero overhead on the success path

### Optimization Guidance

1. Use `:hash` strategy for cache locality (same args → same node)
2. Use `sticky_node: true` to avoid repeated selection overhead
3. Prefer static node lists over MFA for hot paths
4. Set `error_handling: false` on performance-critical, non-critical paths
5. Use `RpcWrapper` (compile-time config) instead of `DefRpc` when topology is stable
6. Leave `sleep_before_retry` at `0` (default) for latency-sensitive paths;
   set it only where giving a remote service recovery time is more important
   than fast failure propagation

---

## Security Considerations

### Authentication

- Relies on Erlang distributed authentication (cookie-based)
- No additional authentication layer in EasyRpc

### Authorization

- No built-in authorization; implement in remote modules
- Consider adding module allowlists at the application level

### Data Protection

- Data transmitted over Erlang distribution protocol
- Consider TLS distribution for sensitive environments
- No encryption at the EasyRpc layer

---

## Monitoring & Observability

### Current Logging

All log lines follow the format `[EasyRpc] <symbol> module.function/arity on node [meta]`:

| Symbol | Level   | Event                                   |
|--------|---------|-----------------------------------------|
| `-->`  | debug   | RPC call initiated                      |
| `<--`  | debug   | RPC call succeeded                      |
| `<<<`  | warning | Attempt failed, retrying (includes sleep info when > 0) |
| `!!!`  | error   | All attempts exhausted, permanently failed |

### Recommended Additions

1. **Telemetry events** via `:telemetry` for metrics dashboards
2. **Distributed tracing** with OpenTelemetry / `otel_api`
3. **Circuit breakers** (e.g. `:fuse`) for fault tolerance
4. **Node health checks** before selection

---

## Testing Strategy

### Unit Testing

- Test each module in isolation (`async: true` where safe)
- Use `Node.self()` as a loopback node for real `:erpc` calls without a cluster
- Mock `RpcExecutor` behavior for executor-independent tests
- Validate all error formatting and classification paths

### Integration Testing

- Multi-node setup for realistic distributed scenarios
- Simulate network failures / node downs
- Verify retry exhaustion and logging output
- Use wall-clock timing assertions to verify `sleep_before_retry` fires
  the correct number of times (once per retry, never on success or first attempt)

### Key Testing Notes

- `Application.put_env` for configs used by `use RpcWrapper` / `use DefRpc`
  **must be called at module body level**, not inside `setup_all` — wrapper
  modules are compiled before test callbacks run.
- When testing `sleep_before_retry`, use `retry: 1` or `retry: 2` with a
  sleep value large enough to be measurable (≥ 50 ms) but small enough not
  to slow the suite noticeably.

---

## Conclusion

The EasyRpc architecture is designed for:

- **Clarity**: Easy to understand and navigate
- **Maintainability**: Clean separation of concerns, DRY via `FunctionGenerator`
- **Extensibility**: Behavior-based design
- **Reliability**: Comprehensive error handling with structured logging and safe node selection
- **Performance**: Minimal overhead, multiple optimization paths
- **Type Safety**: Complete typespec coverage

The modular design ensures that each component can be tested, extended, or
replaced independently while maintaining overall system integrity.

---

**Last Updated:** 2025
**Version:** 0.8.0
