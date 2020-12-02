defmodule JsonDataFakerTest do
  use ExUnit.Case
  use ExUnitProperties

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

  property "string uuid generation should work" do
    schema = %{"type" => "string", "format" => "uuid"}

    check all(data <- JsonDataFaker.generate(schema)) do
      assert {:ok, _} = UUID.info(data)
    end
  end

  Enum.each(["date-time", "email", "hostname", "ipv4", "ipv6", "uri"], fn format ->
    property "string #{format} generation should work" do
      schema = %{"type" => "string", "format" => unquote(format)}
      resolved_schema = Schema.resolve(schema)

      check all(data <- JsonDataFaker.generate(schema)) do
        assert Validator.valid?(resolved_schema, data)
      end
    end
  end)

  property "string regex generation should work" do
    schema = %{"type" => "string", "pattern" => "^(\\([0-9]{3}\\))?[0-9]{3}-[0-9]{4}$"}
    resolved_schema = Schema.resolve(schema)

    check all(data <- JsonDataFaker.generate(schema)) do
      assert Validator.valid?(resolved_schema, data)
    end
  end

  property "string enum generation should work" do
    schema = %{"type" => "string", "enum" => ["active", "completed"]}
    resolved_schema = Schema.resolve(schema)

    check all(data <- JsonDataFaker.generate(schema)) do
      assert Validator.valid?(resolved_schema, data)
    end
  end

  property "string with max / min length should work" do
    schema = %{"type" => "string", "minLength" => 200, "maxLength" => 201}
    resolved_schema = Schema.resolve(schema)

    check all(data <- JsonDataFaker.generate(schema)) do
      assert Validator.valid?(resolved_schema, data)
    end
  end

  property "integer generation should work" do
    schema = %{"type" => "integer", "minimum" => 5, "maximum" => 20}
    resolved_schema = Schema.resolve(schema)

    check all(data <- JsonDataFaker.generate(schema)) do
      assert Validator.valid?(resolved_schema, data)
    end
  end

  property "complex object generation should work" do
    resolved_schema = Schema.resolve(@complex_object)

    check all(data <- JsonDataFaker.generate(@complex_object)) do
      assert Validator.valid?(resolved_schema, data)
    end
  end

  property "array of object generation should work" do
    schema = %{
      "items" => @complex_object,
      "type" => "array"
    }

    resolved_schema = Schema.resolve(schema)

    check all(data <- JsonDataFaker.generate(schema)) do
      assert Validator.valid?(resolved_schema, data)
    end
  end

  property "empty or invalid schema should return nil" do
    schema = %{}

    check all(data <- JsonDataFaker.generate(schema)) do
      assert is_nil(data)
    end

    schema = nil

    check all(data <- JsonDataFaker.generate(schema)) do
      assert is_nil(data)
    end

    schema = []

    check all(data <- JsonDataFaker.generate(schema)) do
      assert is_nil(data)
    end
  end
end
