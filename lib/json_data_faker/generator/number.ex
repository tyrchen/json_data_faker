defmodule JsonDataFaker.Generator.Number do
  @moduledoc false

  import StreamData

  def generate(%{"type" => "integer"} = schema, _root, _opts) do
    generate_integer(
      schema["minimum"],
      schema["maximum"],
      Map.get(schema, "exclusiveMinimum", false),
      Map.get(schema, "exclusiveMaximum", false),
      schema["multipleOf"]
    )
  end

  def generate(%{"type" => "number"} = schema, _root, _opts) do
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

  defp generate_integer(nil, nil, _, _, nil), do: integer()

  defp generate_integer(nil, nil, _, _, multipleOf), do: map(integer(), &(&1 * multipleOf))

  defp generate_integer(min, nil, exclusive, _, nil),
    do: map(positive_integer(), &(&1 - 1 + min + if(exclusive, do: 1, else: 0)))

  defp generate_integer(nil, max, _, exclusive, nil),
    do: map(positive_integer(), &(max + if(exclusive, do: -1, else: 0) - (&1 - 1)))

  defp generate_integer(min, nil, exclusive, _, multipleOf) do
    min = min + if(exclusive, do: 1, else: 0)
    min = Integer.floor_div(min, multipleOf) + if(rem(min, multipleOf) == 0, do: 0, else: 1)
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

    if min > max do
      msg = "number/integer 'minimum' greater than corresponding 'maximum'"
      raise JsonDataFaker.InvalidSchemaError, message: msg
    else
      integer(min..max)
    end
  end

  defp generate_integer(min, max, emin, emax, multipleOf) do
    min = min + if(emin, do: 1, else: 0)
    max = max + if(emax, do: -1, else: 0)
    min = Integer.floor_div(min, multipleOf) + if(rem(min, multipleOf) == 0, do: 0, else: 1)
    max = Integer.floor_div(max, multipleOf)

    if min > max do
      msg = "number/integer 'minimum' greater than corresponding 'maximum'"
      raise JsonDataFaker.InvalidSchemaError, message: msg
    else
      map(integer(min..max), &(&1 * multipleOf))
    end
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
