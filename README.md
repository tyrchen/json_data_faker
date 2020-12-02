# JsonDataFaker

Generate JSON data from JSON schema by using faking data.

```elixir
iex> object_schema = %{
    "properties" => %{
      "body" => %{
        "maxLength" => 140,
        "minLength" => 3,
        "type" => "string"
      },
      "created" => %{
        "format" => "date-time",
        "type" => "string"
      },
      "id" => %{
        "format" => "uuid",
        "type" => "string"
      },
      "status" => %{
        "enum" => [
          "active",
          "completed"
        ],
        "type" => "string"
      },
      "updated" => %{
        "format" => "date-time",
        "type" => "string"
      }
    },
    "required" => [
      "body"
    ],
    "type" => "object"
  }

iex> schema = %{
  "items" => object_schema,
  "type" => "array"
}

iex> schema |> JsonDataFaker.generate() |> Enum.take(1) |> List.first()
[
  %{
    "body" => "Do you think I am easier to be played on than a pipe?",
    "created" => "2020-11-28T01:15:35.268463Z",
    "id" => "13543d9c-0f37-482d-84d6-52b2cb8c1b3f",
    "status" => "active",
    "updated" => "2020-11-28T01:15:35.268478Z"
  },
  %{
    "body" => "When sorrows come, they come not single spies, but in battalions.",
    "created" => "2020-11-28T01:15:35.268502Z",
    "id" => "c95ef972-05c9-4132-9525-09c99a15bf01",
    "status" => "completed",
    "updated" => "2020-11-28T01:15:35.268517Z"
  }
  ...
]
```

## Installation

```elixir
def deps do
  [
    {:json_data_faker, "~> 0.2.0"}
  ]
end
```

Documentation: [https://hexdocs.pm/json_data_faker](https://hexdocs.pm/json_data_faker).
