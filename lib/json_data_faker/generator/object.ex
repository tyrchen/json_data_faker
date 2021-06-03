defmodule JsonDataFaker.Generator.Object do
  @moduledoc false

  # see https://github.com/whatyouhide/stream_data/pull/133
  @dialyzer {:no_opaque, [pattern_properties_generator: 6]}

  def generate(%{"required" => [_ | _] = req, "maxProperties" => max_prop}, _root, _opts)
      when max_prop < length(req),
      do: StreamData.constant(nil)

  def generate(
        %{"additionalProperties" => false, "minProperties" => min_prop} = schema,
        _root,
        _opts
      )
      when not is_map_key(schema, "patternProperties") and
             (not is_map_key(schema, "properties") or
                map_size(:erlang.map_get("properties", schema)) < min_prop),
      do: StreamData.constant(nil)

  def generate(%{"type" => "object"} = schema, root, opts) do
    required = Map.get(schema, "required", [])

    {required_props, optional_props} =
      schema
      |> Map.get("properties", %{})
      |> Enum.split_with(&(elem(&1, 0) in required))

    pattern_props = schema |> Map.get("patternProperties", %{}) |> Map.to_list()

    additional_props = Map.get(schema, "additionalProperties", %{})

    if Keyword.get(opts, :require_optional_properties, false) do
      generate_full_object(
        schema,
        required_props,
        optional_props,
        pattern_props,
        additional_props,
        root,
        opts
      )
    else
      generate_object(
        schema,
        required_props,
        optional_props,
        pattern_props,
        additional_props,
        root,
        opts
      )
    end
  end

  defp generate_full_object(
         schema,
         required_props,
         optional_props,
         pattern_props,
         _additional_props,
         root,
         opts
       ) do
    max_prop = schema["maxProperties"]
    min_prop = schema["minProperties"] || 0

    req_count = length(required_props)
    opt_count = length(optional_props)
    min_pattern_props = min_prop - req_count - opt_count

    optional_props
    |> (&if(max_prop, do: Enum.take(&1, max_prop - req_count), else: &1)).()
    |> Enum.concat(required_props)
    |> streamdata_map_builder_args(root, opts)
    |> StreamData.fixed_map()
    |> merge_map_generators(
      pattern_properties_generator(
        pattern_props,
        required_props,
        optional_props,
        min_pattern_props,
        root,
        opts
      ),
      schema["maxProperties"]
    )
  end

  defp generate_object(
         schema,
         required_props,
         optional_props,
         pattern_props,
         _additional_props,
         root,
         opts
       ) do
    max_prop = schema["maxProperties"]
    min_prop = schema["minProperties"] || 0

    req_count = length(required_props)
    opt_count = length(optional_props)

    {optional_required_props, optional_props} =
      if(req_count < min_prop,
        do: Enum.split(optional_props, min_prop - req_count),
        else: {[], optional_props}
      )

    required_map =
      required_props
      |> Enum.concat(optional_required_props)
      |> streamdata_map_builder_args(root, opts)

    optional_map = streamdata_map_builder_args(optional_props, root, opts)

    min_pattern_props = min_prop - req_count - opt_count

    required_map
    |> StreamData.fixed_map()
    |> merge_map_generators(StreamData.optional_map(optional_map), max_prop)
    |> merge_map_generators(
      pattern_properties_generator(
        pattern_props,
        required_props,
        optional_props,
        min_pattern_props,
        root,
        opts
      ),
      max_prop
    )
  end

  defp pattern_properties_generator(pp, rp, op, min_props, root, opts) when min_props < 0,
    do: pattern_properties_generator(pp, rp, op, 0, root, opts)

  defp pattern_properties_generator(
         [],
         _required_props,
         _optional_props,
         _min_props,
         _root,
         _opts
       ),
       do: StreamData.constant(%{})

  defp pattern_properties_generator(
         pattern_properties,
         required_props,
         optional_props,
         min_props,
         root,
         opts
       ) do
    # if the generated property has the same name of a standard property of the object than
    # it should be valid against the standar property schema and not against the
    # patternProperty one. In order to avoid generation of invalid properties we filter out
    # patternProperties with name equal to one of the standard properties
    other_props_names = required_props |> Enum.concat(optional_props) |> Enum.map(&elem(&1, 0))

    pattern_properties
    |> Enum.map(fn {key_regex, schema} ->
      pattern_property_generator(key_regex, schema, other_props_names, root, opts)
    end)
    |> StreamData.one_of()
    |> StreamData.list_of(min_length: min_props)
    |> StreamData.bind(&(&1 |> Map.new() |> StreamData.constant()))
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

  defp streamdata_map_builder_args(properties, root, opts) do
    Map.new(properties, fn {key, inner_schema} ->
      {key, JsonDataFaker.generate_by_type(inner_schema, root, opts)}
    end)
  end

  defp merge_map_generators(map1_gen, map2_gen, nil) do
    StreamData.bind(map1_gen, fn map1 ->
      StreamData.bind(map2_gen, fn map2 ->
        StreamData.constant(Map.merge(map1, map2))
      end)
    end)
  end

  defp merge_map_generators(map1_gen, map2_gen, max_keys) do
    StreamData.bind(map1_gen, fn map1 ->
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
