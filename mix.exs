defmodule JsonDataFaker.MixProject do
  use Mix.Project

  @version "0.2.0"
  def project do
    [
      app: :json_data_faker,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "JsonDataFaker",
      docs: [
        main: "JsonDataFaker",
        extras: ["README.md"]
      ],
      source_url: "https://github.com/tyrchen/json_data_faker",
      homepage_url: "https://github.com/tyrchen/json_data_faker",
      description: """
      Build API routes based on OpenAPI v3 spec.
      """,
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
      {:ex_json_schema, "~> 0.7"},
      {:randex, "~> 0.4.0"},
      {:faker, "~> 0.15.0"},
      {:uuid, "~> 1.1"},
      {:stream_data, "~> 0.5"},
      {:combination, ">= 0.0.0"},

      # dev/test deps
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test]},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      licenses: ["MIT"],
      maintainers: ["tyr.chen@gmail.com"],
      links: %{
        "GitHub" => "https://github.com/tyrchen/json_data_faker",
        "Docs" => "https://hexdocs.pm/json_data_faker"
      }
    ]
  end
end
