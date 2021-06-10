defmodule JsonDataFaker.Utils do
  @moduledoc false

  def json do
    simple_value =
      StreamData.one_of([
        StreamData.boolean(),
        StreamData.integer(),
        StreamData.string(:ascii),
        StreamData.float()
      ])

    StreamData.tree(simple_value, fn leaf ->
      StreamData.one_of([StreamData.list_of(leaf), StreamData.map_of(json_key(), leaf)])
    end)
  end

  def json_key do
    key_chars = Enum.concat([?a..?z, ?A..?Z, [?-, ?_]])
    StreamData.string(key_chars, min_length: 1)
  end

  def schema_resolve(%{"$ref" => ref}, root), do: ExJsonSchema.Schema.get_fragment!(root, ref)
  def schema_resolve(schema, _root), do: schema

  def stream_gen(fun), do: StreamData.map(StreamData.constant(nil), fn _ -> fun.() end)
end
