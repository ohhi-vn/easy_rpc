defmodule EasyRpc.MixProject do
  use Mix.Project

  def project do
    [
      app: :easy_rpc,
      version: "0.4.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "EasyRpc",
      source_url: "https://github.com/ohhi-vn/easy_rpc",
      homepage_url: "https://ohhi.vn",
      docs: docs(),
      description: description(),
      package: package()
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
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:benchee, "~> 1.3", only: :dev},
    ]
  end

  defp description() do
    "A library for wrapping rpc call from a remote nodes to call like local function. Easy to wrap a remote functions to a local functions."
  end

  defp package() do
    [
      maintainers: ["Manh Van Vu"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ohhi-vn/easy_rpc", "About us" => "https://ohhi.vn/"}
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

    list = list ++ ["README.md"]

    list
    |> Enum.map(fn path ->
      title =
        path
        |> Path.basename(".md")
        |> String.split(~r|[-_]|)
        |> Enum.map_join(" ", &String.capitalize/1)
        |> case do
          "F A Q" ->"FAQ"
          no_change -> no_change
        end

      {String.to_atom(path),
        [
          title: title,
          default: title == "Guide"
        ]
      }
    end)
  end
end
