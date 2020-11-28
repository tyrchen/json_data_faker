defmodule JsonDataFaker.MixProject do
  use Mix.Project

  def project do
    [
      app: :json_data_faker,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:uuid, "~> 1.1"}
    ]
  end
end
