defmodule JsonDataFakerTest.Helpers do
  defmacro property_test(name, schema) do
    quote do
      property unquote(name) do
        resolved_schema = ExJsonSchema.Schema.resolve(unquote(schema))

        check all(data <- JsonDataFaker.generate(unquote(schema))) do
          assert ExJsonSchema.Validator.valid?(resolved_schema, data)
        end
      end
    end
  end
end

defmodule JsonDataFakerTest do
  use ExUnit.Case
  use ExUnitProperties
  import JsonDataFakerTest.Helpers

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
    property_test("string #{format} generation should work", %{
      "type" => "string",
      "format" => unquote(format)
    })
  end)

  property_test("string regex generation should work", %{
    "type" => "string",
    "pattern" => "^(\\([0-9]{3}\\))?[0-9]{3}-[0-9]{4}$"
  })

  property_test("string enum generation should work", %{
    "type" => "string",
    "enum" => ["active", "completed"]
  })

  property_test("string with max / min length should work", %{
    "type" => "string",
    "minLength" => 200,
    "maxLength" => 201
  })

  property_test("integer generation should work", %{
    "type" => "integer",
    "minimum" => 5,
    "maximum" => 20
  })


  property_test("complex object generation should work", @complex_object)

  property_test("array of object generation should work", %{
    "items" => @complex_object,
    "type" => "array"
  })

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
