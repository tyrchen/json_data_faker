defmodule JsonDataFakerTest do
  use ExUnit.Case
  alias ExJsonSchema.{Validator, Schema}
  doctest JsonDataFaker

  @complex_object %{
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

  test "string uuid generation should work" do
    schema = %{"type" => "string", "format" => "uuid"}
    assert {:ok, _} = UUID.info(JsonDataFaker.generate(schema))
  end

  Enum.each(["date-time", "email", "hostname", "ipv4", "ipv6", "uri"], fn format ->
    test "string #{format} generation should work" do
      schema = %{"type" => "string", "format" => unquote(format)}
      s = JsonDataFaker.generate(schema)
      assert Validator.valid?(Schema.resolve(schema), s)
    end
  end)

  test "string regex generation should work" do
    schema = %{"type" => "string", "pattern" => "^(\\([0-9]{3}\\))?[0-9]{3}-[0-9]{4}$"}
    s = JsonDataFaker.generate(schema)
    assert Validator.valid?(Schema.resolve(schema), s)
  end

  test "string enum generation should work" do
    schema = %{"type" => "string", "enum" => ["active", "completed"]}
    s = JsonDataFaker.generate(schema)
    assert Validator.valid?(Schema.resolve(schema), s)
  end

  test "string with max / min length should work" do
    schema = %{"type" => "string", "minLength" => 200, "maxLength" => 201}
    s = JsonDataFaker.generate(schema)
    assert Validator.valid?(Schema.resolve(schema), s)
  end

  test "integer generation should work" do
    schema = %{"type" => "integer", "minimum" => 5, "maximum" => 20}
    s = JsonDataFaker.generate(schema)
    assert Validator.valid?(Schema.resolve(schema), s)
  end

  test "complex object generation should work" do
    s = JsonDataFaker.generate(@complex_object)
    assert Validator.valid?(Schema.resolve(@complex_object), s)
  end

  test "array of object generation should work" do
    schema = %{
      "items" => @complex_object,
      "type" => "array"
    }

    s = JsonDataFaker.generate(schema)
    assert Validator.valid?(Schema.resolve(schema), s)
  end

  test "empty or invalid schema should return nil" do
    schema = %{}
    assert is_nil(JsonDataFaker.generate(schema))
    schema = nil
    assert is_nil(JsonDataFaker.generate(schema))

    schema = []
    assert is_nil(JsonDataFaker.generate(schema))
  end
end
