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
      iex> %{"title" => _title} = JsonDataFaker.generate(schema) |> Enum.take(1) |> List.first()
  """
  def generate(schema, opts \\ [])

  def generate(%Schema.Root{} = schema, opts) do
    generate_by_type(schema.schema, schema, opts)
  end

  def generate(schema, opts) when is_map(schema) do
    schema
    |> Schema.resolve()
    |> generate(opts)
  rescue
    e ->
      Logger.error("Failed to generate data. #{inspect(e)}")
      nil
  end

  def generate(_schema, _opts), do: nil

  # private functions
  defp generate_by_type(%{"$ref" => _} = schema, root, opts) do
    schema
    |> resolve(root)
    |> generate_by_type(root, opts)
  end

  defp generate_by_type(%{"oneOf" => oneOf}, root, opts),
    do: oneOf |> Enum.map(&generate_by_type(&1, root, opts)) |> StreamData.one_of()

  defp generate_by_type(%{"anyOf" => anyOf}, root, opts),
    do: anyOf |> Enum.map(&generate_by_type(&1, root, opts)) |> StreamData.one_of()

  defp generate_by_type(%{"enum" => choices}, _root, _opts), do: StreamData.member_of(choices)

  defp generate_by_type(%{"type" => "boolean"}, _root, _opts), do: boolean()

  defp generate_by_type(%{"type" => "string"} = schema, _root, _opts), do: generate_string(schema)

  defp generate_by_type(%{"type" => "integer"} = schema, _root, _opts) do
    generate_integer(
      schema["minimum"],
      schema["maximum"],
      Map.get(schema, "exclusiveMinimum", false),
      Map.get(schema, "exclusiveMaximum", false),
      schema["multipleOf"]
    )
  end

  defp generate_by_type(%{"type" => "array"} = schema, root, _opts) do
    inner_schema = schema["items"]

    opts =
      Enum.reduce(schema, [], fn
        {"minItems", min}, acc -> Keyword.put(acc, :min_length, min)
        {"maxItems", max}, acc -> Keyword.put(acc, :max_length, max)
        _, acc -> acc
      end)

    case Map.get(schema, "uniqueItems", false) do
      false ->
        StreamData.list_of(generate_by_type(inner_schema, root, opts), opts)

      true ->
        inner_schema
        |> generate_by_type(root, opts)
        |> StreamData.scale(fn size ->
          case Keyword.get(opts, :max_length, false) do
            false -> size
            max -> max * 3
          end
        end)
        |> StreamData.uniq_list_of(opts)
    end
  end

  defp generate_by_type(%{"type" => "object", "properties" => _} = schema, root, opts) do
    case Keyword.get(opts, :require_optional_properties, false) do
      true -> generate_full_object(schema, root, opts)
      false -> generate_object(schema, root, opts)
    end
  end

  defp generate_by_type(_schema, _root, _opts), do: StreamData.constant(nil)

  defp generate_full_object(%{"properties" => properties}, root, opts) do
    properties
    |> Map.new(fn {key, inner_schema} -> {key, generate_by_type(inner_schema, root, opts)} end)
    |> StreamData.fixed_map()
  end

  defp generate_object(%{"properties" => properties} = schema, root, opts) do
    required = Map.get(schema, "required", [])
    {required_props, optional_props} = Enum.split_with(properties, &(elem(&1, 0) in required))

    [required_map, optional_map] =
      Enum.map([required_props, optional_props], fn props ->
        Map.new(props, fn {key, inner_schema} ->
          {key, generate_by_type(inner_schema, root, opts)}
        end)
      end)

    required_map
    |> StreamData.fixed_map()
    |> StreamData.bind(fn req_map ->
      StreamData.bind(StreamData.optional_map(optional_map), fn opt_map ->
        StreamData.constant(Map.merge(opt_map, req_map))
      end)
    end)
  end

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

  defp generate_string(%{"pattern" => regex}),
    do: Randex.stream(Regex.compile!(regex), mod: Randex.Generator.StreamData, max_repetition: 10)

  defp generate_string(schema) do
    opts =
      Enum.reduce(schema, [], fn
        {"minLength", min}, acc -> Keyword.put(acc, :min_length, min)
        {"maxLength", max}, acc -> Keyword.put(acc, :max_length, max)
        _, acc -> acc
      end)

    string(:ascii, opts)
  end

  defp generate_integer(nil, nil, _, _, nil), do: integer()

  defp generate_integer(nil, nil, _, _, multipleOf), do: map(integer(), &(&1 * multipleOf))

  defp generate_integer(min, nil, exclusive, _, nil),
    do: map(positive_integer(), &(&1 - 1 + min + if(exclusive, do: 1, else: 0)))

  defp generate_integer(nil, max, _, exclusive, nil),
    do: map(positive_integer(), &(max + if(exclusive, do: -1, else: 0) - (&1 - 1)))

  defp generate_integer(min, nil, exclusive, _, multipleOf) do
    min = min + if(exclusive, do: 1, else: 0)
    min = Integer.floor_div(min, multipleOf) + 1
    map(positive_integer(), &((&1 - 1 + min) * multipleOf))
  end

  defp generate_integer(nil, max, _, exclusive, multipleOf) do
    max = max + if(exclusive, do: -1, else: 0)
    max = Integer.floor_div(max, multipleOf)
    map(positive_integer(), &((max - (&1 - 1)) * multipleOf))
  end

  defp generate_integer(min, max, emin, emax, nil) do
    min = min + if(emin, do: 1, else: 0)
    max = max + if(emax, do: -1, else: 0)
    integer(min..max)
  end

  defp generate_integer(min, max, emin, emax, multipleOf) do
    min = min + if(emin, do: 1, else: 0)
    max = max + if(emax, do: -1, else: 0)
    min = Integer.floor_div(min, multipleOf) + 1
    max = Integer.floor_div(max, multipleOf)
    map(integer(min..max), &(&1 * multipleOf))
  end

  defp stream_gen(fun) do
    StreamData.map(StreamData.constant(nil), fn _ -> fun.() end)
  end

  defp resolve(%{"$ref" => ref}, root), do: ExJsonSchema.Schema.get_fragment!(root, ref)
  defp resolve(schema, _root), do: schema
end
