defmodule JsonDataFaker.Generator.Array do
  @moduledoc false

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
      JsonDataFaker.Generator.Utils.json(),
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
        do: JsonDataFaker.Generator.Utils.json(),
        else: JsonDataFaker.generate_by_type(ai, root, opts)
      ),
      items,
      schema["minItems"],
      schema["maxItems"],
      root,
      opts
    )
  end

  def generate(%{"items" => inner_schema} = schema, root, _opts)
      when is_map(inner_schema) do
    opts =
      Enum.reduce(schema, [], fn
        {"minItems", min}, acc -> Keyword.put(acc, :min_length, min)
        {"maxItems", max}, acc -> Keyword.put(acc, :max_length, max)
        _, acc -> acc
      end)

    case Map.get(schema, "uniqueItems", false) do
      false ->
        StreamData.list_of(JsonDataFaker.generate_by_type(inner_schema, root, opts), opts)

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
