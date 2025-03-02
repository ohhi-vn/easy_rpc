import Config

config :libcluster,
  topologies: [
    local_epmd: [
      # The selected clustering strategy. Required.
      strategy: Cluster.Strategy.Epmd,
      # Configuration for the provided strategy. Optional.
      config: [
        hosts: [
        :"remote@127.0.0.1",
        :"example@127.0.0.1"
        ]
      ]
    ]
  ]

  config :simple_example, :remote_wrapper,
    nodes: [:"remote@127.0.0.1"],
    error_handling: true,
    select_mode: :random,
    module: RemoteNode.Interface,
    functions: [
      # {function_name, arity}
      {:say_hello, 0},
      {:say_hello_to, 1},
      # {function_name, arity, opts}
      {:say_hello_to_with_age, 2, [new_name: :hello_with_name_age]},
      {:raise_exception, 0, [new_name: :fail, retry: 3, error_handling: true]}
    ]
