defmodule JsonDataFaker.Generator.Array do
  @moduledoc false

  def generate(%{"additionalItems" => ai, "items" => [_ | _] = items}, root, opts)
      when is_boolean(ai) do
    items
    |> Enum.map(&JsonDataFaker.generate_by_type(&1, root, opts))
    |> StreamData.fixed_list()
  end

  def generate(%{"additionalItems" => schema, "items" => [_ | _] = items}, root, opts)
      when is_map(schema) do
    items
    |> Enum.map(&JsonDataFaker.generate_by_type(&1, root, opts))
    |> StreamData.fixed_list()
    |> StreamData.bind(fn fixed_list ->
      additional_generator =
        StreamData.list_of(JsonDataFaker.generate_by_type(schema, root, opts))

      StreamData.bind(additional_generator, fn additional ->
        StreamData.constant(Enum.concat(fixed_list, additional))
      end)
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
end
