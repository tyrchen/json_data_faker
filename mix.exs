defmodule JsonDataFaker.MixProject do
  use Mix.Project

  @version "0.1.0"
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
      {:faker, "~> 0.16"},
      {:uuid, "~> 1.1"},

      # dev/test deps
      {:ex_doc, "~> 0.23", only: :dev, runtime: false}
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
