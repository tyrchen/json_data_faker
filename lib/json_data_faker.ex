defmodule JsonDataFaker do
  @moduledoc """
  Generate fake data based on json schema.
  """
  import StreamData
  require Logger
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
      iex> %{"title" => _title, "body" => _body} = JsonDataFaker.generate(schema) |> Enum.take(1) |> List.first()
  """
  def generate(%Schema.Root{} = schema) do
    generate_by_type(schema.schema)
  end

  def generate(schema) when is_map(schema) do
    generate(Schema.resolve(schema))
  rescue
    e ->
      Logger.error("Failed to generate data. #{inspect(e)}")
      nil
  end

  def generate(_schema), do: nil

  # private functions
  defp generate_by_type(%{"type" => "boolean"}) do
    boolean()
  end

  defp generate_by_type(%{"type" => "string"} = schema) do
    generate_string(schema)
  end

  defp generate_by_type(%{"type" => "integer"} = schema) do
    min = schema["minimum"] || 10
    max = schema["maximum"] || 1000
    integer(min..max)
  end

  defp generate_by_type(%{"type" => "array"} = schema) do
    inner_schema = schema["items"]
    count = Enum.random(2..5)

    StreamData.list_of(generate_by_type(inner_schema), length: count)
  end

  defp generate_by_type(%{"type" => "object"} = schema) do
    stream_gen(fn ->
      Enum.reduce(schema["properties"], %{}, fn {k, inner_schema}, acc ->
        v = inner_schema |> generate_by_type() |> Enum.take(1) |> List.first()

        Map.put(acc, k, v)
      end)
    end)
  end

  defp generate_by_type(_schema), do: StreamData.constant(nil)

  defp generate_string(%{"format" => "date-time"}),
    do: stream_gen(fn -> 30 |> Faker.DateTime.backward() |> DateTime.to_iso8601() end)

  defp generate_string(%{"format" => "uuid"}), do: stream_gen(&Faker.UUID.v4/0)
  defp generate_string(%{"format" => "email"}), do: stream_gen(&Faker.Internet.email/0)

  defp generate_string(%{"format" => "hostname"}),
    do: stream_gen(&Faker.Internet.domain_name/0)

  defp generate_string(%{"format" => "ipv4"}), do: stream_gen(&Faker.Internet.ip_v4_address/0)
  defp generate_string(%{"format" => "ipv6"}), do: stream_gen(&Faker.Internet.ip_v6_address/0)
  defp generate_string(%{"format" => "uri"}), do: stream_gen(&Faker.Internet.url/0)

  defp generate_string(%{"format" => "image_uri"}) do
    stream_gen(fn ->
      w = Enum.random(1..4) * 400
      h = Enum.random(1..4) * 400
      "https://source.unsplash.com/random/#{w}x#{h}"
    end)
  end

  defp generate_string(%{"enum" => choices}), do: StreamData.member_of(choices)

  defp generate_string(%{"pattern" => regex}),
    do: Randex.stream(Regex.compile!(regex), mod: Randex.Generator.StreamData)

  defp generate_string(schema) do
    min = schema["minLength"] || 0
    max = schema["maxLength"] || 1024

    stream_gen(fn ->
      s = Faker.Lorem.word()

      case String.length(s) do
        v when v > max -> String.slice(s, 0, max - 1)
        v when v < min -> String.slice(Faker.Lorem.sentence(min), 0, min)
        _ -> s
      end
    end)
  end

  defp stream_gen(fun) do
    StreamData.map(StreamData.constant(nil), fn _ -> fun.() end)
  end
end
