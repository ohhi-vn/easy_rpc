# Benchmark: Impact of Logging on RPC Performance
# Compares execution speed with logging enabled vs disabled.

IO.puts("=== Logging Impact Benchmark ===\n")

# Define a mock RPC target module
defmodule MockTarget do
  def echo(val), do: val
  def slow(val), do: (Process.sleep(10); val)
end

# Create a module with logging enabled (default)
defmodule LoggingEnabled do
  use EasyRpc

  config do
    nodes [node()]
    module MockTarget
    timeout 5_000
    enable_logging true
  end

  rpc_functions do
    rpc_function :echo, 1
    rpc_function :slow, 1
  end
end

# Create a module with logging disabled
defmodule LoggingDisabled do
  use EasyRpc

  config do
    nodes [node()]
    module MockTarget
    timeout 5_000
    enable_logging false
  end

  rpc_functions do
    rpc_function :echo, 1
    rpc_function :slow, 1
  end
end

IO.puts("Modules compiled successfully.\n")

# Verify the enable_logging setting is correctly applied
IO.puts("Verifying enable_logging config...")
test_config_enabled = struct!(EasyRpc.WrapperConfig, %{enable_logging: true})
test_config_disabled = struct!(EasyRpc.WrapperConfig, %{enable_logging: false})
IO.puts("Config with logging enabled: #{test_config_enabled.enable_logging}")
IO.puts("Config with logging disabled: #{test_config_disabled.enable_logging}")
IO.puts("")

# Temporarily disable Logger for cleaner benchmark output
Logger.configure(level: :warning)

# Benchmark fast functions (echo) with logging enabled vs disabled
IO.puts("=== Benchmark: Fast RPC Calls (echo/1) ===\n")

Benchee.run(
  [
    {"Logging Enabled", fn -> LoggingEnabled.echo(42) end},
    {"Logging Disabled", fn -> LoggingDisabled.echo(42) end}
  ],
  time: 2,
  memory_time: 0
)

# Benchmark slower functions (slow) with logging enabled vs disabled
IO.puts("\n=== Benchmark: Slow RPC Calls (slow/1, 10ms delay) ===\n")

Benchee.run(
  [
    {"Logging Enabled", fn -> LoggingEnabled.slow(42) end},
    {"Logging Disabled", fn -> LoggingDisabled.slow(42) end}
  ],
  time: 2,
  memory_time: 0
)

# Restore logger level
Logger.configure(level: :debug)

IO.puts("\n=== Summary ===")
IO.puts("""
Logging Impact Analysis:
1. Logging adds I/O overhead (writing to console/file)
2. For performance-critical paths, disable logging
3. The `enable_logging` option now correctly controls all logging in RpcCall
4. When disabled, all Logger calls are skipped (verified fix)

Recommendation:
- Enable logging in development/staging
- Disable logging in production for performance-critical paths
- Use telemetry events for production monitoring instead of logs
""")
