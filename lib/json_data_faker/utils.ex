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

    key_chars = Enum.concat([?a..?z, ?A..?Z, [?-, ?_]])
    map_key = StreamData.string(key_chars, min_length: 1)

    StreamData.tree(simple_value, fn leaf ->
      StreamData.one_of([StreamData.list_of(leaf), StreamData.map_of(map_key, leaf)])
    end)
  end
end
