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
end
