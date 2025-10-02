# EasyRpc Architecture Documentation

**Version:** 0.6.0  
**Last Updated:** 2024  
**Status:** Production Ready

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
- **Backward Compatibility**: Legacy support while introducing modern patterns

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
                                │(Compat)      │  │  (Compat)     │
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
└── Config Loading                └── Runtime Config Loading
```

### Layer 3: Utilities & Shared Logic
```
FunctionGenerator                  WrapperConfig               NodeSelector
├── normalize/1                   ├── load_config!/2          ├── new/4
├── resolve_name/2                ├── load_from_options!/1    ├── select_node/2
├── merge_config/2                ├── validate!/1             ├── Strategy: random
├── parse_arity/1                 └── Type Specs              ├── Strategy: round_robin
└── generate_arg_vars/1                                       ├── Strategy: hash
                                                              └── Sticky Node Support
```

### Layer 4: Core Execution
```
RpcCall (implements RpcExecutor)
├── execute/3
├── execute_with_retry/3
├── execute_dynamic/4
├── Error Handling
├── Retry Logic
└── Structured Logging
```

### Layer 5: Cross-Cutting Concerns
```
Error (Unified)                   RpcExecutor (Behavior)
├── Type: config_error           ├── Callback: execute/3
├── Type: rpc_error              ├── Callback: execute_with_retry/3
├── Type: node_error             └── Callback: validate_config/1
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

**Purpose:** Generate wrapper functions from configuration

**Responsibilities:**
- Read function definitions from config
- Generate wrapper functions at compile time
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
Config File → load_config!/2 → WrapperConfig
                                      ↓
Function List → FunctionGenerator → Generated Functions
                                      ↓
Runtime Call → RpcCall.execute/3 → Remote Result
```

---

### 3. DefRpc (Declarative Approach)

**Purpose:** Explicitly declare each wrapped function

**Responsibilities:**
- Provide `defrpc` macro for function declaration
- Support per-function configuration
- Load node config dynamically at runtime

**Usage Pattern:**
```elixir
defmodule MyApi do
  use EasyRpc.DefRpc,
    otp_app: :my_app,
    config_name: :nodes_config,
    module: RemoteModule

  defrpc :get_user, args: 1
  defrpc :create_user, args: 2, retry: 3
end
```

**Architecture:**
```
defrpc Macro → Parse Options → FunctionGenerator
                                      ↓
Generated Function → Load Node Config → RpcCall.execute_dynamic/4
                                      ↓
Remote Call → Result
```

---

### 4. FunctionGenerator (Utility Module)

**Purpose:** Extract common function generation logic

**Responsibilities:**
- Normalize function specifications
- Merge global and per-function configs
- Parse arity specifications
- Generate function arguments
- Validate function options

**Key Functions:**
- `normalize_function_info/1` - Standardize function specs
- `resolve_function_name/2` - Handle name overrides
- `merge_config/2` - Combine global and local configs
- `parse_arity/1` - Handle various arity formats
- `generate_arg_vars/1` - Create argument variables

**Benefits:**
- DRY principle adherence
- Consistent behavior between wrappers
- Easier testing and maintenance

---

### 5. WrapperConfig (Configuration Management)

**Purpose:** Validate and manage RPC configuration

**Responsibilities:**
- Load configuration from various sources
- Validate all configuration parameters
- Provide type-safe config structure
- Define function specifications

**Configuration Sources:**
1. Application config file
2. Keyword list options
3. Direct struct creation

**Validation Rules:**
- `module`: must be non-nil atom
- `timeout`: positive integer or `:infinity`
- `retry`: non-negative integer
- `error_handling`: boolean
- `functions`: list of valid function specs
- `node_selector`: valid NodeSelector or nil

---

### 6. NodeSelector (Selection Strategy)

**Purpose:** Select target nodes for RPC calls

**Responsibilities:**
- Implement node selection strategies
- Manage sticky node state
- Support dynamic node discovery
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
hash(args) % num_nodes → node_index
["user123"] → hash → 2 → node3
["user123"] → hash → 2 → node3 (consistent)
```

#### Sticky Node (Per Process)
```
First call: select node1
All subsequent calls in same process: node1
```

**State Management:**
- Uses process dictionary for per-process state
- Keys: `{:easy_rpc, :sticky_node, id}`, `{:easy_rpc, :round_robin, id}`
- Isolated per selector ID

---

### 7. RpcCall (Executor)

**Purpose:** Execute remote procedure calls

**Responsibilities:**
- Implement `RpcExecutor` behavior
- Execute RPC with error handling
- Implement retry logic
- Manage timeouts
- Provide structured logging

**Execution Modes:**

#### Without Error Handling
```elixir
execute(config, :get_user, [123])
#=> %User{id: 123}  # Or raises exception
```

#### With Error Handling
```elixir
execute(config, :get_user, [123])
#=> {:ok, %User{id: 123}}
#=> {:error, %EasyRpc.Error{...}}
```

#### With Retry
```elixir
config = %{config | retry: 3}
execute_with_retry(config, :get_user, [123])
# Retries up to 3 times on failure
#=> {:ok, result} | {:error, error}
```

**Call Flow:**
```
execute/3
    ↓
select_node (NodeSelector)
    ↓
:erpc.call(node, module, function, args, timeout)
    ↓
Success → log_result → return
    OR
Exception → handle_exception
    ↓
    retry? → Yes → execute again
           → No → {:error, error}
```

---

### 8. Error (Unified Error Handling)

**Purpose:** Provide consistent error handling

**Responsibilities:**
- Define error types and structure
- Wrap exceptions with context
- Format error messages
- Log errors appropriately
- Maintain backward compatibility

**Error Structure:**
```elixir
%EasyRpc.Error{
  type: :rpc_error,
  message: "Connection refused",
  details: [
    node: :remote@host,
    attempt: 2,
    original_exception: ErlangError
  ]
}
```

**Error Types:**
- `:config_error` - Configuration validation failures
- `:rpc_error` - Remote call failures
- `:node_error` - Node connection/selection issues
- `:timeout_error` - Call timeout
- `:validation_error` - Input validation failures

**Helper Functions:**
- `wrap_exception/2` - Convert exceptions to EasyRpc.Error
- `format/1` - Human-readable error string
- `log/2` - Log with appropriate level
- `raise!/1-3` - Raise structured error

---

### 9. RpcExecutor (Behavior)

**Purpose:** Define contract for RPC execution

**Callbacks:**
```elixir
@callback execute(config, function, args) :: result | raw_result
@callback execute_with_retry(config, function, args) :: result
@callback validate_config(config) :: :ok | {:error, term}
```

**Benefits:**
- Clear interface definition
- Enables testing with mocks
- Allows alternative implementations
- Documents expected behavior

---

## Data Flow

### Complete Request Flow

```
1. User Code
   MyApi.get_user(123)
        ↓
2. Generated Wrapper Function
   - Loads WrapperConfig
   - Applies function-specific options
        ↓
3. RpcCall.execute/3
   - Select node (NodeSelector)
   - Log call start
        ↓
4. :erpc.call/5
   - Network call to remote node
   - Execute RemoteModule.get_user(123)
        ↓
5. Response Handling
   - Success → log + return result
   - Exception → wrap + retry or return error
        ↓
6. Return to User
   - Raw result or {:ok, result} / {:error, error}
```

### Configuration Loading Flow

```
Application.get_env(:my_app, :config_name)
        ↓
WrapperConfig.load_config!/2
        ↓
Validate all parameters
        ↓
NodeSelector.load_config!/2
        ↓
Validate node configuration
        ↓
Return validated WrapperConfig
```

### Error Handling Flow

```
Remote Call Fails
        ↓
Exception Raised
        ↓
RpcCall catches exception
        ↓
Error.wrap_exception/2
        ↓
Check retry configuration
        ↓
Yes → Log warning + retry
No  → Log error + return {:error, error}
```

---

## Design Patterns

### 1. Behavior Pattern
- **Module:** `RpcExecutor`
- **Purpose:** Define clear contracts
- **Benefit:** Testability and extensibility

### 2. Strategy Pattern
- **Module:** `NodeSelector`
- **Purpose:** Pluggable node selection strategies
- **Strategies:** Random, Round Robin, Hash, Sticky

### 3. Template Method Pattern
- **Module:** `RpcCall`
- **Purpose:** Common execution flow with customizable error handling
- **Variants:** With/without error handling, with/without retry

### 4. Facade Pattern
- **Module:** `EasyRpc`, `RpcWrapper`, `DefRpc`
- **Purpose:** Simple interface to complex subsystem
- **Benefit:** Easy to use, hides complexity

### 5. Adapter Pattern
- **Modules:** `ConfigError`, `RpcError`
- **Purpose:** Backward compatibility while using new Error module
- **Benefit:** Smooth migration path

### 6. Builder Pattern
- **Module:** `WrapperConfig`
- **Purpose:** Flexible configuration construction
- **Methods:** `new!`, `load_config!`, `load_from_options!`

---

## Extension Points

### 1. Custom RPC Executor

Implement the `RpcExecutor` behavior:

```elixir
defmodule MyCustomExecutor do
  @behaviour EasyRpc.Behaviours.RpcExecutor

  @impl true
  def execute(config, function, args) do
    # Custom implementation
    # Could add: connection pooling, custom metrics, etc.
  end

  @impl true
  def execute_with_retry(config, function, args) do
    # Custom retry logic
  end
end
```

### 2. Custom Node Selection Strategy

While not currently pluggable, could be extended:

```elixir
# Future enhancement
defmodule MyCustomStrategy do
  @behaviour EasyRpc.Behaviours.NodeStrategy

  @impl true
  def select(nodes, context) do
    # Custom logic: weighted, health-based, etc.
  end
end
```

### 3. Custom Error Types

Extend the Error module:

```elixir
defmodule MyApp.CustomErrors do
  def business_error(message, details \\ []) do
    EasyRpc.Error.validation_error(message, 
      Keyword.put(details, :type, :business_logic))
  end
end
```

### 4. Telemetry Integration

Add telemetry events:

```elixir
# In custom executor
:telemetry.execute(
  [:my_app, :rpc, :call],
  %{duration: duration},
  %{node: node, function: function}
)
```

---

## Component Relationships

### Dependency Graph

```
EasyRpc (main)
    ↓
RpcWrapper, DefRpc (wrappers)
    ↓
FunctionGenerator (utilities)
    ↓
WrapperConfig, NodeSelector (config)
    ↓
RpcCall (executor)
    ↓
RpcExecutor (behavior), Error (cross-cutting)
```

### Compile-Time vs Runtime

**Compile-Time:**
- Function generation (macros)
- Configuration validation
- Typespec checking

**Runtime:**
- Node selection
- RPC execution
- Error handling
- Logging
- Retry logic

---

## Performance Considerations

### Memory Footprint
- Minimal: mostly function definitions
- Process dictionary for sticky/round-robin state
- No global state or ETS tables

### Execution Overhead
- Function call: ~0.1μs (macro-generated)
- Node selection: ~1-5μs (random/hash) to ~10μs (MFA call)
- RPC call: Network latency (typically 1-50ms LAN)
- Error handling: ~10-50μs (when enabled)

### Optimization Points
1. **Hash strategy** for cache locality
2. **Sticky nodes** to reduce selection overhead
3. **Static node lists** vs dynamic MFA
4. **Disabled error handling** for performance-critical paths

---

## Security Considerations

### Authentication
- Relies on Erlang distributed authentication
- Cookie-based node authentication
- No additional authentication layer

### Authorization
- No built-in authorization
- Should be implemented in remote modules
- Consider adding module allowlists

### Data Protection
- Data transmitted over Erlang distribution protocol
- Consider TLS for sensitive data
- No encryption at EasyRpc layer

---

## Monitoring & Observability

### Current Logging
- Structured log messages
- Multiple log levels (debug, info, warning, error)
- Context in error messages

### Recommended Additions
1. **Telemetry events** for metrics
2. **Distributed tracing** with OpenTelemetry
3. **Health checks** for nodes
4. **Circuit breakers** for fault tolerance

---

## Testing Strategy

### Unit Testing
- Test each module independently
- Mock behaviors (RpcExecutor)
- Validate configuration logic
- Test error formatting

### Integration Testing
- Multi-node setup
- Real RPC calls
- Network failure simulation
- Retry behavior verification

### Property-Based Testing
- Node selection distribution
- Configuration validation
- Error wrapping correctness

---

## Conclusion

The EasyRpc architecture is designed for:
- **Clarity**: Easy to understand and navigate
- **Maintainability**: Clean separation of concerns
- **Extensibility**: Behavior-based design
- **Reliability**: Comprehensive error handling
- **Performance**: Minimal overhead
- **Type Safety**: Complete typespec coverage

The modular design ensures that each component can be tested, extended, or replaced independently while maintaining the overall system integrity.

---

**Last Updated:** 2024  
**Version:** 0.6.0  
**Architecture Status:** ✅ Production Ready