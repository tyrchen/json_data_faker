defmodule JsonDataFaker.Generator.Object do
  @moduledoc false

  def generate(%{"type" => "object", "properties" => _} = schema, root, opts) do
    case Keyword.get(opts, :require_optional_properties, false) do
      true -> generate_full_object(schema, root, opts)
      false -> generate_object(schema, root, opts)
    end
  end

  def generate(%{"type" => "object"}, _root, _opts), do: StreamData.constant(%{})

  defp generate_full_object(%{"properties" => properties}, root, opts) do
    properties
    |> Map.new(fn {key, inner_schema} ->
      {key, JsonDataFaker.generate_by_type(inner_schema, root, opts)}
    end)
    |> StreamData.fixed_map()
  end

  defp generate_object(%{"properties" => properties} = schema, root, opts) do
    required = Map.get(schema, "required", [])
    {required_props, optional_props} = Enum.split_with(properties, &(elem(&1, 0) in required))

    [required_map, optional_map] =
      Enum.map([required_props, optional_props], fn props ->
        Map.new(props, fn {key, inner_schema} ->
          {key, JsonDataFaker.generate_by_type(inner_schema, root, opts)}
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
end
