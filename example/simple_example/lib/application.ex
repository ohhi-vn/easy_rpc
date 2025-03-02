defmodule SimpleExample.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.fetch_env!(:libcluster, :topologies)

    children =
        [{Cluster.Supervisor, [topologies, [name: SimpleExample.ClusterSupervisor]]}]

    opts = [strategy: :one_for_one, name: SimpleExample.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
