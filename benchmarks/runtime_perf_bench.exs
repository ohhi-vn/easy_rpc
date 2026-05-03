# Runtime Performance Benchmark
# Compares execution speed of RPC calls between Spark DSL and Macro style.
# Note: This uses local node calls via :erpc to avoid network dependencies.

IO.puts("=== Runtime Performance Benchmark: Spark DSL vs Macro Style ===\n")

# Define a mock RPC target module
defmodule MockTarget do
  def echo(val), do: val
  def add(a, b), do: a + b
  def slow(val), do: (Process.sleep(10); val)
end

# Create Spark DSL module
defmodule SparkRuntimeBench do
  use EasyRpc

  config do
    nodes [node()]
    module MockTarget
    timeout 5_000
  end

  rpc_functions do
    rpc_function :echo, 1
    rpc_function :add, 2
    rpc_function :slow, 1
  end
end

# Create DefRpc macro module with inline config
defmodule DefRpcRuntimeBench do
  use EasyRpc.DefRpc,
    otp_app: :my_app,
    config_name: :bench_config,
    module: MockTarget,
    timeout: 5_000

  defrpc :echo, args: 1
  defrpc :add, args: 2
  defrpc :slow, args: 1
end

# Need to create the config for DefRpc
Application.put_env(:my_app, :bench_config,
  nodes: [node()],
  select_mode: :random,
  module: MockTarget
)

IO.puts("Modules compiled successfully.\n")

# Benchmark fast functions (echo)
IO.puts("=== Benchmark: Fast RPC Calls (echo/1) ===\n")

Benchee.run(
  [
    {"Spark DSL", fn -> SparkRuntimeBench.echo(42) end},
    {"DefRpc Macro", fn -> DefRpcRuntimeBench.echo(42) end}
  ],
  time: 2,
  memory_time: 0
)

# Benchmark functions with arguments (add/2)
IO.puts("\n=== Benchmark: RPC with Arguments (add/2) ===\n")

Benchee.run(
  [
    {"Spark DSL", fn -> SparkRuntimeBench.add(1, 2) end},
    {"DefRpc Macro", fn -> DefRpcRuntimeBench.add(1, 2) end}
  ],
  time: 2,
  memory_time: 0
)

# Benchmark slower functions
IO.puts("\n=== Benchmark: Slower RPC Calls (slow/1, 10ms delay) ===\n")

Benchee.run(
  [
    {"Spark DSL", fn -> SparkRuntimeBench.slow(42) end},
    {"DefRpc Macro", fn -> DefRpcRuntimeBench.slow(42) end}
  ],
  time: 2,
  memory_time: 0
)

IO.puts("\n=== Summary ===")
IO.puts("""
Runtime Performance Analysis:
1. Both styles ultimately call RpcCall.execute/3
2. Spark DSL adds a transformer layer at compile time
3. DefRpc macro generates functions at compile time
4. Runtime overhead should be nearly identical (same underlying execution)

Key Insight:
The performance difference at runtime should be minimal since both ultimately
use the same RpcCall.execute/3 function with the same WrapperConfig.
The main differences are in:
- Compile-time code generation approach
- DSL expressiveness and tooling support

Note: These benchmarks use local node calls via :erpc.
For real RPC benchmarks, deploy to multiple nodes and test with actual network calls.
""")
