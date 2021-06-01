defmodule JsonDataFaker.Generator.Utils do
  @moduledoc false

  def json do
    simple_value =
      StreamData.one_of([
        StreamData.boolean(),
        StreamData.integer(),
        StreamData.string(:printable),
        StreamData.float()
      ])

    map_key = StreamData.string(:printable, min_length: 1)

    StreamData.tree(simple_value, fn leaf ->
      StreamData.one_of([StreamData.list_of(leaf), StreamData.map_of(map_key, leaf)])
    end)
  end
end
