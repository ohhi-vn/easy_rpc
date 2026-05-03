# Spark DSL Style Benchmark

This directory contains benchmarks to compare the new Spark DSL style with the old macro style.

## Files

- `bench_helper.exs` - Helper module for benchmarks
- `spark_dsl_bench.exs` - Benchmark Spark DSL style
- `macro_style_bench.exs` - Benchmark macro style (DefRpc/RpcWrapper)
- `run_all.exs` - Run all benchmarks and compare

## Usage

```bash
# Run all benchmarks
mix run benchmarks/run_all.exs

# Run individual benchmarks
mix run benchmarks/spark_dsl_bench.exs
mix run benchmarks/macro_style_bench.exs
```

## Metrics Compared

1. **Compilation Time** - Time to compile modules
2. **Runtime Performance** - Execution time of RPC calls
3. **Memory Usage** - Memory overhead of generated modules
4. **Code Generation** - Time to generate wrapper functions
