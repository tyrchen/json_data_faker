defmodule JsonDataFaker do
  @moduledoc """
  Generate fake data based on json schema.
  """
  import StreamData
  require Logger
  alias ExJsonSchema.Schema

  if Mix.env() == :test do
    defp unshrink(stream), do: stream
  else
    defp unshrink(stream), do: StreamData.unshrinkable(stream)
  end

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
    schema.schema
    |> generate_by_type(schema, opts)
    |> unshrink()
  end

  def generate(schema, opts) when is_map(schema) do
    schema
    |> Schema.resolve()
    |> generate(opts)
    |> unshrink()
  rescue
    e ->
      Logger.error("Failed to generate data. #{inspect(e)}")
      StreamData.constant(nil)
  end

  def generate(_schema, _opts), do: StreamData.constant(nil)

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

  defp generate_by_type(%{"allOf" => allOf}, root, opts) do
    allOf
    |> merge_all_of(root)
    |> generate_by_type(root, opts)
  end

  defp generate_by_type(%{"enum" => choices}, _root, _opts), do: StreamData.member_of(choices)

  defp generate_by_type(%{"type" => [_ | _] = types} = schema, root, opts) do
    types
    |> Enum.map(fn type -> Map.put(schema, "type", type) end)
    |> Enum.map(&generate_by_type(&1, root, opts))
    |> StreamData.one_of()
  end

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

  defp generate_by_type(%{"type" => "number"} = schema, _root, _opts) do
    int_generator =
      generate_integer(
        float_min_to_int(schema["minimum"]),
        float_max_to_int(schema["maximum"]),
        if(float_is_int(schema["minimum"]),
          do: Map.get(schema, "exclusiveMinimum", false),
          else: false
        ),
        if(float_is_int(schema["maximum"]),
          do: Map.get(schema, "exclusiveMaximum", false),
          else: false
        ),
        schema["multipleOf"]
      )

    float_generator =
      if schema["multipleOf"] != nil do
        map(int_generator, &(&1 * 1.0))
      else
        generate_float(
          schema["minimum"],
          schema["maximum"],
          Map.get(schema, "exclusiveMinimum", false),
          Map.get(schema, "exclusiveMaximum", false)
        )
      end

    StreamData.one_of([int_generator, float_generator])
  end

  defp generate_by_type(
         %{"type" => "array", "additionalItems" => ai, "items" => [_ | _] = items},
         root,
         opts
       )
       when is_boolean(ai) do
    items
    |> Enum.map(&generate_by_type(&1, root, opts))
    |> StreamData.fixed_list()
  end

  defp generate_by_type(
         %{"type" => "array", "additionalItems" => schema, "items" => [_ | _] = items},
         root,
         opts
       )
       when is_map(schema) do
    items
    |> Enum.map(&generate_by_type(&1, root, opts))
    |> StreamData.fixed_list()
    |> StreamData.bind(fn fixed_list ->
      additional_generator = StreamData.list_of(generate_by_type(schema, root, opts))

      StreamData.bind(additional_generator, fn additional ->
        StreamData.constant(Enum.concat(fixed_list, additional))
      end)
    end)
  end

  defp generate_by_type(%{"type" => "array", "items" => inner_schema} = schema, root, _opts)
       when is_map(inner_schema) do
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

  defp generate_by_type(%{"type" => "array"}, _root, _opts), do: StreamData.constant([])

  defp generate_by_type(%{"type" => "object", "properties" => _} = schema, root, opts) do
    case Keyword.get(opts, :require_optional_properties, false) do
      true -> generate_full_object(schema, root, opts)
      false -> generate_object(schema, root, opts)
    end
  end

  defp generate_by_type(%{"type" => "object"}, _root, _opts), do: StreamData.constant(%{})

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

  defp generate_float(nil, nil, _, _), do: float()

  defp generate_float(min, nil, false, _), do: float(min: min)

  defp generate_float(min, nil, true, _), do: filter(float(min: min), &(&1 != min))

  defp generate_float(nil, max, _, false), do: float(max: max)

  defp generate_float(nil, max, _, true), do: filter(float(max: max), &(&1 != max))

  defp generate_float(min, max, emin, emax) do
    [min: min, max: max]
    |> float()
    |> (&if(emin, do: filter(&1, fn val -> val != min end), else: &1)).()
    |> (&if(emax, do: filter(&1, fn val -> val != max end), else: &1)).()
  end

  defp stream_gen(fun) do
    StreamData.map(StreamData.constant(nil), fn _ -> fun.() end)
  end

  defp merge_all_of(all_ofs, root) do
    all_of_merger_root = fn root -> &all_of_merger(&1, &2, &3, root) end

    Enum.reduce(all_ofs, %{}, fn all_of, acc ->
      Map.merge(acc, resolve(all_of, root), all_of_merger_root.(root))
    end)
  end

  defp all_of_merger(key, v1, v2, _root)
       when key in ["minLength", "minProperties", "minimum", "maxItems"],
       do: max(v1, v2)

  defp all_of_merger(key, v1, v2, _root)
       when key in ["maxLength", "maxProperties", "maximum", "minItems"],
       do: min(v1, v2)

  defp all_of_merger(key, v1, v2, _root)
       when key in ["uniqueItems", "exclusiveMaximum", "exclusiveMinimum"],
       do: v1 or v2

  defp all_of_merger("multipleOf", v1, v2, _root) do
    # TODO fix
    case Integer.gcd(v1, v2) do
      1 -> v1 * v2
      _ -> max(v1, v2)
    end
  end

  defp all_of_merger("enum", v1, v2, _root), do: Enum.filter(v1, &(&1 in v2))

  defp all_of_merger("required", v1, v2, _root), do: v1 |> Enum.concat(v2) |> Enum.uniq()

  defp all_of_merger(_property, %{"$ref" => _} = v1, %{"$ref" => _} = v2, root) do
    f1 = resolve(v1, root)
    f2 = resolve(v2, root)
    all_of_merger_root = fn root -> &all_of_merger(&1, &2, &3, root) end
    Map.merge(f1, f2, all_of_merger_root.(root))
  end

  defp all_of_merger(_key, m1, m2, root) when is_map(m1) and is_map(m2) do
    all_of_merger_root = fn root -> &all_of_merger(&1, &2, &3, root) end
    Map.merge(m1, m2, all_of_merger_root.(root))
  end

  defp all_of_merger(_key, _v1, v2, _root), do: v2

  defp resolve(%{"$ref" => ref}, root), do: ExJsonSchema.Schema.get_fragment!(root, ref)
  defp resolve(schema, _root), do: schema

  defp float_is_int(num) when is_integer(num), do: true
  defp float_is_int(num) when is_float(num), do: Float.round(num) == 1.0 * num
  defp float_is_int(_), do: false

  defp float_min_to_int(nil), do: nil
  defp float_min_to_int(num) when is_integer(num), do: num

  defp float_min_to_int(num) do
    cond do
      float_is_int(num) -> trunc(num)
      num < 0 -> trunc(num)
      num > 0 -> trunc(num) + 1
    end
  end

  defp float_max_to_int(nil), do: nil
  defp float_max_to_int(num) when is_integer(num), do: num

  defp float_max_to_int(num) do
    cond do
      float_is_int(num) -> trunc(num)
      num < 0 -> trunc(num) - 1
      num > 0 -> trunc(num)
    end
  end
end
