defmodule JsonDataFaker.Generator.Misc do
  @moduledoc false

  def generate(%{"$ref" => _} = schema, root, opts) do
    schema
    |> resolve(root)
    |> JsonDataFaker.generate_by_type(root, opts)
  end

  def generate(%{"oneOf" => oneOf}, root, opts),
    do: oneOf |> Enum.map(&JsonDataFaker.generate_by_type(&1, root, opts)) |> StreamData.one_of()

  def generate(%{"anyOf" => anyOf}, root, opts),
    do: anyOf |> Enum.map(&JsonDataFaker.generate_by_type(&1, root, opts)) |> StreamData.one_of()

  def generate(%{"allOf" => allOf}, root, opts) do
    allOf
    |> merge_all_of(root)
    |> JsonDataFaker.generate_by_type(root, opts)
  end

  def generate(%{"enum" => choices}, _root, _opts), do: StreamData.member_of(choices)

  def generate(%{"type" => [_ | _] = types} = schema, root, opts) do
    types
    |> Enum.map(fn type -> Map.put(schema, "type", type) end)
    |> Enum.map(&JsonDataFaker.generate_by_type(&1, root, opts))
    |> StreamData.one_of()
  end

  defp merge_all_of(all_ofs, root) do
    all_of_merger_root = fn root -> &all_of_merger(&1, &2, &3, root) end

    Enum.reduce(all_ofs, %{}, fn all_of, acc ->
      Map.merge(acc, resolve(all_of, root), all_of_merger_root.(root))
    end)
  end

  defp all_of_merger(key, v1, v2, _root)
       when key in ["minLength", "minProperties", "minimum", "minItems"],
       do: max(v1, v2)

  defp all_of_merger(key, v1, v2, _root)
       when key in ["maxLength", "maxProperties", "maximum", "maxItems"],
       do: min(v1, v2)

  defp all_of_merger(key, v1, v2, _root)
       when key in ["uniqueItems", "exclusiveMaximum", "exclusiveMinimum"],
       do: v1 or v2

  defp all_of_merger("multipleOf", v1, v2, _root), do: lcm(v1, v2)

  defp all_of_merger("enum", v1, v2, _root), do: Enum.filter(v1, &(&1 in v2))

  defp all_of_merger("required", v1, v2, _root), do: v1 |> Enum.concat(v2) |> Enum.uniq()

  defp all_of_merger(_property, %{"$ref" => _} = v1, %{"$ref" => _} = v2, root) do
    f1 = resolve(v1, root)
    f2 = resolve(v2, root)
    all_of_merger(nil, f1, f2, root)
  end

  defp all_of_merger(_key, m1, m2, root) when is_map(m1) and is_map(m2) do
    all_of_merger_root = fn root -> &all_of_merger(&1, &2, &3, root) end
    Map.merge(m1, m2, all_of_merger_root.(root))
  end

  # NOTE
  # here fall also "pattern" and "format" keywords
  # there is no easy way of merging them so we keep only the second value
  # be aware that this can lead to generated values that are not valid against the schema
  defp all_of_merger(_key, _v1, v2, _root), do: v2

  defp resolve(%{"$ref" => ref}, root), do: ExJsonSchema.Schema.get_fragment!(root, ref)
  defp resolve(schema, _root), do: schema

  defp lcm(m, n), do: trunc(m * n / Integer.gcd(m, n))
end
