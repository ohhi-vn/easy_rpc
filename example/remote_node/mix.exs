defmodule RemoteNode.MixProject do
  use Mix.Project

  def project do
    [
      app: :remote_node,
      version: "0.1.0",
      elixir: "~> 1.15",
      config_path: "config/config.exs",
      lockfile: "mix.lock",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {RemoteNode.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:libcluster, "~> 3.5"}
    ]
  end
end
