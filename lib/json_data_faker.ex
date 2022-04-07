defmodule JsonDataFaker do
  @moduledoc """
  Generate fake data based on json schema.
  """
  import StreamData
  require Logger

  alias ExJsonSchema.Schema

  alias JsonDataFaker.Generator.{Array, Misc, Number, Object, String}

  defmodule InvalidSchemaError do
    defexception [:message]
  end

  defmodule GenerationError do
    defexception [:message]
  end

  if Mix.env() == :test do
    defp unshrink(stream), do: stream
  else
    defp unshrink(stream), do: StreamData.unshrinkable(stream)
  end

  @string_keys ["pattern", "minLength", "maxLength"]
  @number_keys ["multipleOf", "maximum", "exclusiveMaximum", "minimum", "exclusiveMinimum"]
  @array_keys ["additionalItems", "items", "maxItems", "minItems", "uniqueItems"]
  @object_keys [
    "maxProperties",
    "minProperties",
    "required",
    "additionalProperties",
    "properties",
    "patternProperties"
  ]

  @misc_keys ["$ref", "oneOf", "anyOf", "allOf", "not", "enum"]

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
      iex> %{"title" => _title} = JsonDataFaker.generate!(schema) |> Enum.take(1) |> List.first()
  """
  def generate!(schema, opts \\ [])

  def generate!(schema, opts) when is_map(schema) do
    {root, schema} =
      case schema do
        %Schema.Root{} ->
          {schema, schema.schema}

        _ ->
          root = Schema.resolve(schema)
          {root, root.schema}
      end

    schema
    |> generate_by_type(root, opts)
    |> unshrink()
  rescue
    e in JsonDataFaker.InvalidSchemaError ->
      reraise e, __STACKTRACE__

    e ->
      %struct{} = e

      case Module.split(struct) do
        ["ExJsonSchema" | _] ->
          reraise JsonDataFaker.InvalidSchemaError, [message: e.message], __STACKTRACE__

        ["StreamData" | _] ->
          reraise JsonDataFaker.GenerationError, [message: e.message], __STACKTRACE__

        _ ->
          reraise e, __STACKTRACE__
      end
  end

  def generate!(schema, _opts) do
    msg = "invalid schema, it should be a map or a resolved ExJsonSchema, got #{inspect(schema)}"
    raise JsonDataFaker.InvalidSchemaError, message: msg
  end

  def generate(schema, opts \\ []) do
    {:ok, generate!(schema, opts)}
  rescue
    e -> {:error, e.message}
  end

  @doc false

  for key <- @misc_keys do
    def generate_by_type(schema, root, opts) when is_map_key(schema, unquote(key)),
      do: Misc.generate(schema, root, opts)
  end

  def generate_by_type(%{"type" => [_ | _]} = schema, root, opts),
    do: Misc.generate(schema, root, opts)

  def generate_by_type(%{"type" => "boolean"}, _root, _opts), do: boolean()

  def generate_by_type(%{"type" => "string"} = schema, root, opts),
    do: String.generate(schema, root, opts)

  def generate_by_type(%{"type" => "array"} = schema, root, opts),
    do: Array.generate(schema, root, opts)

  def generate_by_type(%{"type" => "object"} = schema, root, opts),
    do: Object.generate(schema, root, opts)

  def generate_by_type(%{"type" => type} = schema, root, opts) when type in ["integer", "number"],
    do: Number.generate(schema, root, opts)

  def generate_by_type(%{"type" => "null"}, _root, _opts), do: StreamData.constant(nil)

  for key <- @string_keys do
    def generate_by_type(schema, root, opts) when is_map_key(schema, unquote(key)),
      do: schema |> Map.put("type", "string") |> String.generate(root, opts)
  end

  for key <- @number_keys do
    def generate_by_type(schema, root, opts) when is_map_key(schema, unquote(key)),
      do: schema |> Map.put("type", "number") |> Number.generate(root, opts)
  end

  for key <- @array_keys do
    def generate_by_type(schema, root, opts) when is_map_key(schema, unquote(key)),
      do: schema |> Map.put("type", "array") |> Array.generate(root, opts)
  end

  for key <- @object_keys do
    def generate_by_type(schema, root, opts) when is_map_key(schema, unquote(key)),
      do: schema |> Map.put("type", "object") |> Object.generate(root, opts)
  end

  def generate_by_type(_schema, _root, _opts), do: JsonDataFaker.Utils.json()
end
