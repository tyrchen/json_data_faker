defmodule JsonDataFaker.Generator.String do
  @moduledoc false

  alias JsonDataFaker.Utils

  import StreamData, only: [string: 2]

  def generate(%{"format" => "date-time"}, _root, _opts),
    do: Utils.stream_gen(fn -> 30 |> Faker.DateTime.backward() |> DateTime.to_iso8601() end)

  def generate(%{"format" => "uuid"}, _root, _opts), do: Utils.stream_gen(&Faker.UUID.v4/0)

  def generate(%{"format" => "email"}, _root, _opts),
    do: Utils.stream_gen(&Faker.Internet.email/0)

  def generate(%{"format" => "hostname"}, _root, _opts),
    do: Utils.stream_gen(&Faker.Internet.domain_name/0)

  def generate(%{"format" => "ipv4"}, _root, _opts),
    do: Utils.stream_gen(&Faker.Internet.ip_v4_address/0)

  def generate(%{"format" => "ipv6"}, _root, _opts),
    do: Utils.stream_gen(&Faker.Internet.ip_v6_address/0)

  def generate(%{"format" => "uri"}, _root, _opts), do: Utils.stream_gen(&Faker.Internet.url/0)

  def generate(%{"format" => "image_uri"}, _root, _opts) do
    Utils.stream_gen(fn ->
      w = Enum.random(1..4) * 400
      h = Enum.random(1..4) * 400
      "https://source.unsplash.com/random/#{w}x#{h}"
    end)
  end

  def generate(%{"format" => format}, root, opts) do
    case Application.fetch_env(:json_data_faker, :custom_format_generator) do
      :error -> string(:ascii, [])
      {:ok, {mod, fun}} -> apply(mod, fun, [format, root, opts])
    end
  end

  def generate(%{"pattern" => regex}, _root, _opts),
    do: Randex.stream(Regex.compile!(regex), mod: Randex.Generator.StreamData, max_repetition: 10)

  def generate(schema, _root, _opts) do
    opts =
      Enum.reduce(schema, [], fn
        {"minLength", min}, acc -> Keyword.put(acc, :min_length, min)
        {"maxLength", max}, acc -> Keyword.put(acc, :max_length, max)
        _, acc -> acc
      end)

    string(:ascii, opts)
  end
end
