alias BenchHelper

# Compile the helper module
Code.compile_file("benchmarks/bench_helper.ex")

# Define test cases with different numbers of functions
test_cases = [
  {:"Spark_Small", 5},
  {:"Spark_Medium", 20},
  {:"Spark_Large", 50}
]

# Generate quoted modules for each test case
quotes =
  Enum.map(test_cases, fn {name, num_functions} ->
    functions = Enum.map(1..num_functions, fn i -> {:"func_#{i}", 2} end)
    {name, BenchHelper.spark_dsl_module_quote(:"Bench_#{name}", functions)}
  end)

# Run compilation benchmarks
IO.puts("\n=== Compilation Time Benchmark (Spark DSL) ===\n")
IO.puts("Measuring time to compile modules with different numbers of functions...\n")

Benchee.run(
  Enum.map(quotes, fn {name, quoted} ->
    {name, fn -> Code.compile_quoted(quoted) end}
  end),
  time: 1,
  memory_time: 1
)

# Measure memory usage
IO.puts("\n=== Memory Usage Benchmark (Spark DSL) ===\n")

Enum.each(quotes, fn {name, quoted} ->
  {mem_before, mem_after, _} = BenchHelper.measure_memory(quoted)
  mem_diff = mem_after - mem_before
  IO.puts("#{name}: #{BenchHelper.format_bytes(mem_diff)} memory increase")
end)

IO.puts("\nBenchmark complete!")
