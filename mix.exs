defmodule EasyRpc.MixProject do
  use Mix.Project

  def project do
    [
      app: :easy_rpc,
      version: "0.9.1",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "EasyRpc",
      source_url: "https://github.com/ohhi-vn/easy_rpc",
      homepage_url: "https://ohhi.vn",
      docs: docs(),
      description: description(),
      package: package(),
      aliases: aliases(),
      usage_rules: usage_rules()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:spark, "~> 2.6"},

      # Documentation
      {:ex_doc, "~> 0.40", only: :dev},

      # Support for AI agent in dev env
      {:tidewave, "~> 0.5", only: :dev},
      {:bandit, "~> 1.10", only: :dev},
      {:usage_rules, "~> 1.2", only: [:dev]},
      {:benchee, "~> 1.5", only: [:dev]}
    ]
  end

  defp description() do
    "A library for wrapping RPC calls from remote nodes, allowing them to be used like local functions. It provides a simple way to expose remote functions as local APIs."
  end

  defp package() do
    [
      maintainers: ["Manh Van Vu"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/ohhi-vn/easy_rpc",
        "About us" => "https://ohhi.vn/"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: extras()
    ]
  end

  defp extras do
    list =
      "guides/**/*.md"
      |> Path.wildcard()

    list = list ++ ["README.md", "CHANGELOG.md", "CONTRIBUTING.md"]

    list
    |> Enum.map(fn path ->
      title =
        path
        |> Path.basename(".md")
        |> String.split(~r|[-_]|)
        |> Enum.map_join(" ", &String.capitalize/1)
        |> case do
          "F A Q" -> "FAQ"
          "Getting Started" -> "Getting Started"
          "Migration Guide" -> "Migration Guide"
          no_change -> no_change
        end

      {String.to_atom(path),
       [
         title: title,
         default: title == "Getting Started"
       ]}
    end)
  end

  defp aliases do
    [
      tidewave:
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4113) end)'",
      "usage_rules.update": [
        """
        usage_rules.sync AGENTS.md --all \
          --inline usage_rules:all \
          --link-to-folder deps
        """
        |> String.trim()
      ]
    ]
  end

  def usage_rules do
    [
      file: "AGENTS.md",
      usage_rules: :all
    ]
  end
end
