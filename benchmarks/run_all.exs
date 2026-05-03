# Compile the helper module
Code.compile_file("benchmarks/bench_helper.ex")
alias BenchHelper

IO.puts("=== EasyRpc Benchmark: Spark DSL vs Macro Style ===")
IO.puts("This benchmark compares compilation time and memory usage.\n")

# Define test cases
test_cases = [
  {5, "Small (5 functions)"},
  {20, "Medium (20 functions)"},
  {50, "Large (50 functions)"}
]

IO.puts("=== Compilation Time Comparison ===\n")

Enum.each(test_cases, fn {num_functions, label} ->
  functions = Enum.map(1..num_functions, fn i -> {:"func_#{i}", 2} end)

  # Spark DSL
  spark_quoted = BenchHelper.spark_dsl_module_quote(:"SparkBench", functions)
  {spark_time, _} = BenchHelper.measure_compile_time(spark_quoted)

  # DefRpc Macro
  defrpc_quoted = BenchHelper.defrpc_module_quote(:"DefRpcBench", functions)
  {defrpc_time, _} = BenchHelper.measure_compile_time(defrpc_quoted)

  IO.puts("""
  #{label}:
    Spark DSL: #{BenchHelper.format_time(spark_time)}
    DefRpc:    #{BenchHelper.format_time(defrpc_time)}
    Difference: #{Float.round((defrpc_time - spark_time) / spark_time * 100, 1)}%
  """)
end)

IO.puts("\n=== Memory Usage Comparison ===\n")

Enum.each(test_cases, fn {num_functions, label} ->
  functions = Enum.map(1..num_functions, fn i -> {:"func_#{i}", 2} end)

  # Spark DSL
  spark_quoted = BenchHelper.spark_dsl_module_quote(:"SparkMemBench", functions)
  {spark_mem_before, spark_mem_after, _} = BenchHelper.measure_memory(spark_quoted)
  spark_mem_diff = spark_mem_after - spark_mem_before

  # DefRpc Macro
  defrpc_quoted = BenchHelper.defrpc_module_quote(:"DefRpcMemBench", functions)
  {defrpc_mem_before, defrpc_mem_after, _} = BenchHelper.measure_memory(defrpc_quoted)
  defrpc_mem_diff = defrpc_mem_after - defrpc_mem_before

  IO.puts("""
  #{label}:
    Spark DSL: #{BenchHelper.format_bytes(spark_mem_diff)}
    DefRpc:    #{BenchHelper.format_bytes(defrpc_mem_diff)}
  """)
end)

IO.puts("\n=== Summary ===")
IO.puts("""
Spark DSL Benefits:
1. Better tooling (autocomplete, inline docs via elixir_sense)
2. Extensibility (anyone can write extensions)
3. Cleaner architecture (separated DSL definition, transformation, verification)
4. Compile-time validation via verifiers

Macro Style Benefits:
1. Simpler for very basic use cases
2. No additional dependency (Spark)
3. More familiar to developers who know macros

Recommendation:
- Use Spark DSL for new projects or when you need extensibility
- Macro style is still supported via EasyRpc.DefRpc and EasyRpc.RpcWrapper
""")
