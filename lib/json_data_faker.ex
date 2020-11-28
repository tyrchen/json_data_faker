defmodule JsonDataFaker do
  @moduledoc """
  Generate fake data based on json schema.
  """

  alias ExJsonSchema.Schema

  @doc """
  generate fake data with given schema. It could be a raw json schema or ExJsonSchema.Schema.Root type.

  ## Examples

      iex> schema = %{
      ...>  "properties" => %{
      ...>    "body" => %{"maxLength" => 140, "minLength" => 3, "type" => "string"},
      ...>    "title" => %{"maxLength" => 64, "minLength" => 3, "type" => "string"}
      ...>  },
      ...>  "required" => ["title"],
      ...>  "type" => "object"
      ...>}
      iex> %{"title" => title, "body" => body} = JsonDataFaker.generate(schema)
  """
  def generate(%Schema.Root{} = schema) do
    generate_by_type(schema.schema)
  end

  def generate(schema) when is_map(schema) do
    generate(Schema.resolve(schema))
  rescue
    _ ->
      nil
  end

  def generate(_schema), do: nil

  # private functions
  defp generate_by_type(%{"type" => "boolean"}) do
    Enum.random([true, false])
  end

  defp generate_by_type(%{"type" => "string"} = schema) do
    generate_string(schema)
  end

  defp generate_by_type(%{"type" => "integer"} = schema) do
    min = schema["minimum"] || 10
    max = schema["maximum"] || 1000
    Enum.random(min..max)
  end

  defp generate_by_type(%{"type" => "array"} = schema) do
    inner_schema = schema["items"]
    count = Enum.random(2..5)

    Enum.map(1..count, fn _ ->
      generate_by_type(inner_schema)
    end)
  end

  defp generate_by_type(%{"type" => "object"} = schema) do
    Enum.reduce(schema["properties"], %{}, fn {k, inner_schema}, acc ->
      Map.put(acc, k, generate_by_type(inner_schema))
    end)
  end

  defp generate_by_type(_schema), do: nil

  defp generate_string(%{"format" => "date-time"}),
    do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp generate_string(%{"format" => "uuid"}), do: Faker.UUID.v4()
  defp generate_string(%{"format" => "email"}), do: Faker.Internet.email()
  defp generate_string(%{"format" => "hostname"}), do: Faker.Internet.domain_name()
  defp generate_string(%{"format" => "ipv4"}), do: Faker.Internet.ip_v4_address()
  defp generate_string(%{"format" => "ipv6"}), do: Faker.Internet.ip_v6_address()
  defp generate_string(%{"format" => "uri"}), do: Faker.Internet.url()

  defp generate_string(%{"format" => "image_uri"}),
    do: "https://source.unsplash.com/random/400x400"

  defp generate_string(%{"enum" => choices}), do: Enum.random(choices)

  defp generate_string(%{"pattern" => regex}),
    do: Randex.stream(Regex.compile!(regex)) |> Enum.take(1) |> List.first()

  defp generate_string(schema) do
    min = schema["minLength"] || 0
    max = schema["maxLength"] || 1024
    s = Faker.Lorem.word()

    case String.length(s) do
      v when v > max -> String.slice(s, 0, max - 1)
      v when v < min -> String.slice(Faker.Lorem.sentence(min), 0, min)
      _ -> s
    end
  end
end
