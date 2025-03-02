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
