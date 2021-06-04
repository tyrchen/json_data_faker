defmodule JsonDataFaker.Generator.Object do
  @moduledoc false

  # see https://github.com/whatyouhide/stream_data/pull/133
  @dialyzer {:no_opaque, [pattern_properties_generator: 6]}

  def generate(%{"required" => [_ | _] = req, "maxProperties" => max_prop}, _root, _opts)
      when max_prop < length(req) do
    msg = "object 'maxProperties' lower than number of required properties"
    raise JsonDataFaker.InvalidSchemaError, message: msg
  end

  def generate(
        %{"additionalProperties" => false, "minProperties" => min_prop} = schema,
        _root,
        _opts
      )
      when not is_map_key(schema, "patternProperties") and
             (not is_map_key(schema, "properties") or
                map_size(:erlang.map_get("properties", schema)) < min_prop) do
    msg =
      "object 'minProperties' lower than number of possible properties" <>
        "without 'patternProperties' and with 'additionalProperties' false"

    raise JsonDataFaker.InvalidSchemaError, message: msg
  end

  def generate(%{"type" => "object"} = schema, root, opts) do
    required = Map.get(schema, "required", [])

    {required_props, optional_props} =
      schema
      |> Map.get("properties", %{})
      |> Enum.split_with(&(elem(&1, 0) in required))

    pattern_props = schema |> Map.get("patternProperties", %{}) |> Map.to_list()

    additional_props = Map.get(schema, "additionalProperties", %{})

    max_prop = schema["maxProperties"]
    min_prop = schema["minProperties"] || 0
    min_extra_props = min_prop - length(required_props) - length(optional_props)

    schema_info = %{
      required_props: required_props,
      optional_props: optional_props,
      pattern_props: pattern_props,
      additional_props: additional_props,
      max_prop: max_prop,
      min_prop: min_prop,
      min_extra_props: min_extra_props
    }

    if Keyword.get(opts, :require_optional_properties, false) do
      generate_full_object(schema_info, root, opts)
    else
      generate_object(schema_info, root, opts)
    end
  end

  defp generate_full_object(schema_info, root, opts) do
    req_count = length(schema_info.required_props)

    schema_info.optional_props
    |> (&if(schema_info.max_prop,
          do: Enum.take(&1, schema_info.max_prop - req_count),
          else: &1
        )).()
    |> Enum.concat(schema_info.required_props)
    |> streamdata_map_builder_args(root, opts)
    |> StreamData.fixed_map()
    |> add_pattern_properties(schema_info, root, opts)
    |> add_additonal_properties(schema_info, root, opts)
  end

  defp generate_object(schema_info, root, opts) do
    req_count = length(schema_info.required_props)

    {optional_required_props, optional_props} =
      if(req_count < schema_info.min_prop,
        do: Enum.split(schema_info.optional_props, schema_info.min_prop - req_count),
        else: {[], schema_info.optional_props}
      )

    required_map =
      schema_info.required_props
      |> Enum.concat(optional_required_props)
      |> streamdata_map_builder_args(root, opts)

    optional_map = streamdata_map_builder_args(optional_props, root, opts)

    required_map
    |> StreamData.fixed_map()
    |> merge_map_generators(StreamData.optional_map(optional_map), schema_info.max_prop)
    |> add_pattern_properties(schema_info, root, opts)
    |> add_additonal_properties(schema_info, root, opts)
  end

  defp add_pattern_properties(generator, %{min_extra_props: mep}, _, _) when mep <= 0,
    do: generator

  defp add_pattern_properties(generator, %{pattern_props: []}, _, _), do: generator

  defp add_pattern_properties(generator, schema_info, root, opts) do
    # if the generated property has the same name of a standard property of the object than
    # it should be valid against the standar property schema and not against the
    # patternProperty one. In order to avoid generation of invalid properties we filter out
    # patternProperties with name equal to one of the standard properties
    other_props_names =
      schema_info.required_props
      |> Enum.concat(schema_info.optional_props)
      |> Enum.map(&elem(&1, 0))

    pattern_generator = fn previous_map ->
      ms = map_size(previous_map)
      min_length = max(schema_info.min_prop - ms, 0)

      max_length =
        if(is_nil(schema_info.max_prop) or schema_info.max_prop > ms + 2,
          do: min_length + 2,
          else: schema_info.max_prop
        )

      schema_info.pattern_props
      |> Enum.map(fn {key_regex, schema} ->
        pattern_property_generator(key_regex, schema, other_props_names, root, opts)
      end)
      |> StreamData.one_of()
      |> StreamData.list_of(min_length: min_length, max_length: max_length)
      |> StreamData.bind(&(&1 |> Map.new() |> StreamData.constant()))
    end

    merge_map_generators(generator, pattern_generator, nil)
  end

  defp pattern_property_generator(key_regex, schema, keys_blacklist, root, opts) do
    key_generator =
      key_regex
      |> Regex.compile!()
      |> Randex.stream(mod: Randex.Generator.StreamData, max_repetition: 10)
      |> StreamData.filter(&(&1 not in keys_blacklist))

    value_generator = JsonDataFaker.generate_by_type(schema, root, opts)

    StreamData.tuple({key_generator, value_generator})
  end

  defp add_additonal_properties(generator, %{min_extra_props: mep}, _, _)
       when mep <= 0,
       do: generator

  defp add_additonal_properties(generator, %{additional_props: false}, _, _), do: generator

  defp add_additonal_properties(generator, schema_info, root, opts) do
    key_allowed? = additional_key_allowed?(schema_info)

    additional_generator = fn previous_map ->
      ms = map_size(previous_map)
      min_length = max(schema_info.min_prop - ms, 0)

      max_length =
        if(is_nil(schema_info.max_prop) or schema_info.max_prop > ms + 2,
          do: min_length + 2,
          else: schema_info.max_prop
        )

      StreamData.map_of(
        StreamData.filter(JsonDataFaker.Utils.json_key(), &key_allowed?.(&1)),
        if(schema_info.additional_props == true,
          do: JsonDataFaker.Utils.json(),
          else: JsonDataFaker.generate_by_type(schema_info.additional_props, root, opts)
        ),
        min_length: min_length,
        max_length: max_length
      )
    end

    merge_map_generators(generator, additional_generator, nil)
  end

  defp additional_key_allowed?(schema_info) do
    fixed_keys =
      schema_info.required_props
      |> Enum.concat(schema_info.optional_props)
      |> Enum.map(&elem(&1, 0))

    pattern_keys = Enum.map(schema_info.pattern_props, &elem(&1, 0))

    fn key ->
      key not in fixed_keys and
        not Enum.any?(pattern_keys, &(&1 |> Regex.compile!() |> Regex.match?(key)))
    end
  end

  defp streamdata_map_builder_args(properties, root, opts) do
    Map.new(properties, fn {key, inner_schema} ->
      {key, JsonDataFaker.generate_by_type(inner_schema, root, opts)}
    end)
  end

  defp merge_map_generators(map1_gen, map2_gen, nil) do
    StreamData.bind(map1_gen, fn map1 ->
      map2_gen = if(is_function(map2_gen), do: map2_gen.(map1), else: map2_gen)

      StreamData.bind(map2_gen, fn map2 ->
        StreamData.constant(Map.merge(map1, map2))
      end)
    end)
  end

  defp merge_map_generators(map1_gen, map2_gen, max_keys) do
    StreamData.bind(map1_gen, fn map1 ->
      map2_gen = if(is_function(map2_gen), do: map2_gen.(map1), else: map2_gen)

      StreamData.bind(map2_gen, fn map2 ->
        case max_keys - map_size(map1) do
          n when n <= 0 ->
            StreamData.constant(map1)

          n when n >= map_size(map2) ->
            StreamData.constant(Map.merge(map1, map2))

          n ->
            map2
            |> Enum.take(n)
            |> Map.new()
            |> (&Map.merge(map1, &1)).()
            |> StreamData.constant()
        end
      end)
    end)
  end
end
