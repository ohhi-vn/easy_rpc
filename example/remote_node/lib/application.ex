defmodule RemoteNode.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.fetch_env!(:libcluster, :topologies)

    children =
        [{Cluster.Supervisor, [topologies, [name: RemoteNode.ClusterSupervisor]]}]

    opts = [strategy: :one_for_one, name: RemoteNode.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
