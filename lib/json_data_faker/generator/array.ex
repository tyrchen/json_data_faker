defmodule JsonDataFaker.Generator.Array do
  @moduledoc false

  alias JsonDataFaker.Utils

  def generate(
        %{"additionalItems" => false, "items" => [_ | _] = items, "minItems" => min},
        _root,
        _opts
      )
      when length(items) < min,
      do: StreamData.constant(nil)

  def generate(%{"additionalItems" => false, "items" => [_ | _] = items} = schema, root, opts) do
    len = length(items)
    maxItems = schema["maxItems"]
    maxItems = if(not is_nil(maxItems), do: min(maxItems, len), else: len)

    generate_additional_schema(
      Utils.json(),
      items,
      schema["minItems"],
      maxItems,
      root,
      opts
    )
  end

  def generate(%{"additionalItems" => ai, "items" => [_ | _] = items} = schema, root, opts) do
    generate_additional_schema(
      if(is_boolean(ai),
        do: Utils.json(),
        else: JsonDataFaker.generate_by_type(ai, root, opts)
      ),
      items,
      schema["minItems"],
      schema["maxItems"],
      root,
      opts
    )
  end

  def generate(%{"items" => %{"$ref" => _} = inner_schema} = schema, root, opts) do
    schema
    |> Map.put("items", Utils.schema_resolve(inner_schema, root))
    |> generate(root, opts)
  end

  def generate(%{"items" => %{"enum" => enum}, "uniqueItems" => true} = schema, _root, _opts)
      when length(enum) < 12 do
    Utils.stream_gen(fn ->
      len = length(enum)

      (schema["minItems"] || 1)..min(schema["maxItems"] || 5, len)
      |> Enum.flat_map(&Combination.combine(enum, &1))
      |> Enum.random()
    end)
  end

  def generate(%{"items" => inner_schema} = schema, root, _opts)
      when is_map(inner_schema) do
    opts =
      Enum.reduce(schema, [], fn
        {"minItems", min}, acc -> Keyword.put(acc, :min_length, min)
        {"maxItems", max}, acc -> Keyword.put(acc, :max_length, max)
        _, acc -> acc
      end)

    opts =
      case {Keyword.get(opts, :min_length), Keyword.get(opts, :max_length)} do
        {nil, nil} -> Keyword.put(opts, :max_length, 5)
        {minlen, nil} -> Keyword.put(opts, :max_length, minlen + 2)
        _ -> opts
      end

    case Map.get(schema, "uniqueItems", false) do
      false ->
        inner_schema
        |> JsonDataFaker.generate_by_type(root, opts)
        |> StreamData.list_of(opts)

      true ->
        inner_schema
        |> JsonDataFaker.generate_by_type(root, opts)
        |> StreamData.scale(fn size ->
          case Keyword.get(opts, :max_length, false) do
            false -> size
            max -> max * 3
          end
        end)
        |> StreamData.uniq_list_of(opts)
    end
  end

  def generate(_schema, _root, _opts), do: StreamData.constant([])

  defp generate_additional_schema(_additional_generator, _items, _min, 0, _root, _opts),
    do: StreamData.constant([])

  defp generate_additional_schema(_additional_generator, items, _min, max, root, opts)
       when is_integer(max) and max <= length(items) do
    items
    |> Enum.slice(0..(max - 1))
    |> Enum.map(&JsonDataFaker.generate_by_type(&1, root, opts))
    |> StreamData.fixed_list()
  end

  defp generate_additional_schema(additional_generator, items, min, max, root, opts) do
    items
    |> Enum.map(&JsonDataFaker.generate_by_type(&1, root, opts))
    |> StreamData.fixed_list()
    |> concat_list_generators(
      StreamData.list_of(
        additional_generator,
        list_of_opts(length(items), min, max)
      )
    )
  end

  defp list_of_opts(_items_len, nil, nil), do: [max_length: 0]
  defp list_of_opts(items_len, min, nil) when min <= items_len, do: [max_length: 0]

  # avoid generating too many additional items since the schema can be hard to generate
  defp list_of_opts(items_len, min, nil),
    do: [min_length: min - items_len, max_length: min - items_len + 2]

  defp list_of_opts(items_len, nil, max), do: [max_length: max - items_len]

  defp list_of_opts(items_len, min, max) when min <= items_len,
    do: [max_length: max - items_len]

  defp list_of_opts(items_len, min, max),
    do: [min_length: min - items_len, max_length: max - items_len]

  defp concat_list_generators(list1_gen, list2_gen) do
    StreamData.bind(list1_gen, fn list1 ->
      StreamData.bind(list2_gen, fn list2 ->
        StreamData.constant(Enum.concat(list1, list2))
      end)
    end)
  end
end
