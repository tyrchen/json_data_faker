defmodule JsonDataFakerTest.Helpers do
  defmacro property_test(name, schemas) do
    quote do
      property unquote(name) do
        Enum.each(List.wrap(unquote(schemas)), fn schema ->
          resolved_schema = ExJsonSchema.Schema.resolve(schema)

          check all(data <- JsonDataFaker.generate(schema)) do
            assert ExJsonSchema.Validator.valid?(resolved_schema, data)
          end
        end)
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
        "$ref" => "#/components/schemas/Body"
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

  @components %{
    "schemas" => %{
      "Body" => %{
        "enum" => [
          "active",
          "completed"
        ],
        "type" => "string"
      }
    }
  }

  @full_object Map.put(@complex_object, "components", @components)

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

  property_test("enum generation should work", [
    %{
      "type" => "string",
      "enum" => ["active", "completed"]
    },
    %{
      "type" => "integer",
      "enum" => [1, 2, 7]
    },
    %{
      "enum" => [[1, 2], %{"foo" => "bar"}]
    }
  ])

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

  property_test("integer generation with exclusive endpoints should work", %{
    "type" => "integer",
    "minimum" => 3,
    "maximum" => 7,
    "exclusiveMinimum" => true,
    "exclusiveMaximum" => true
  })

  property_test("integer generation with exclusive and negative endpoints should work", %{
    "type" => "integer",
    "minimum" => -7,
    "maximum" => -3,
    "exclusiveMinimum" => true,
    "exclusiveMaximum" => true
  })

  property_test("integer generation with multipleOf and min should work", %{
    "type" => "integer",
    "minimum" => 5,
    "multipleOf" => 3
  })

  property_test("integer generation with multipleOf and negative min should work", %{
    "type" => "integer",
    "minimum" => -5,
    "multipleOf" => 3
  })

  property_test("integer generation with multipleOf and max should work", %{
    "type" => "integer",
    "maximum" => 20,
    "multipleOf" => 3
  })

  property_test("integer generation with multipleOf and negative max should work", %{
    "type" => "integer",
    "maximum" => -20,
    "multipleOf" => 3
  })

  property_test("integer generation with multipleOf should work", %{
    "type" => "integer",
    "minimum" => 5,
    "maximum" => 20,
    "multipleOf" => 3
  })

  property_test("integer generation with multipleOf and negative endpoints should work", %{
    "type" => "integer",
    "minimum" => -20,
    "maximum" => -5,
    "multipleOf" => 3
  })

  property_test(
    "integer generation with multipleOf and exclusive and negative endpoints should work",
    %{
      "type" => "integer",
      "minimum" => -21,
      "maximum" => -3,
      "multipleOf" => 3,
      "exclusiveMinimum" => true,
      "exclusiveMaximum" => true
    }
  )

  property_test("float generation should work", %{
    "type" => "number",
    "minimum" => 5.24,
    "maximum" => 20.33
  })

  property_test("float generation with exclusive endpoints should work", %{
    "type" => "number",
    "minimum" => 3.0,
    "maximum" => 7.789,
    "exclusiveMinimum" => true,
    "exclusiveMaximum" => true
  })

  property_test("float generation with exclusive and negative endpoints should work", %{
    "type" => "number",
    "minimum" => -7.245,
    "maximum" => -3.0,
    "exclusiveMinimum" => true,
    "exclusiveMaximum" => true
  })

  property_test("float generation with multipleOf and negative endpoints should work", %{
    "type" => "number",
    "minimum" => -7.245,
    "maximum" => -3.0,
    "multipleOf" => 2
  })

  property_test("object generation without required properties should work", %{
    "type" => "object",
    "properties" => %{
      "foo" => %{
        "type" => "integer"
      }
    }
  })

  property_test("complex object generation should work", @full_object)

  property "require_optional_properties property should work" do
    resolved_schema = ExJsonSchema.Schema.resolve(@full_object)

    check all(data <- JsonDataFaker.generate(@full_object, require_optional_properties: true)) do
      assert ExJsonSchema.Validator.valid?(resolved_schema, data)
      assert Map.has_key?(data, "status")
    end
  end

  property_test("array of object generation should work", %{
    "items" => @complex_object,
    "type" => "array",
    "components" => @components
  })

  property_test("minItems array generation should work", %{
    "items" => %{"type" => "string"},
    "type" => "array",
    "minItems" => 5
  })

  property_test("maxItems array generation should work", %{
    "items" => %{"type" => "string"},
    "type" => "array",
    "maxItems" => 5
  })

  property_test("uniqueItems array generation should work", %{
    "items" => %{"type" => "string"},
    "type" => "array",
    "uniqueItems" => true
  })

  property_test("array generation with additionalItems bool and array of items should work", [
    %{
      "items" => [%{"type" => "integer"}, %{"type" => "string"}],
      "type" => "array",
      "additionalItems" => false
    },
    %{
      "items" => [%{"type" => "integer"}, %{"type" => "string"}],
      "type" => "array",
      "additionalItems" => true
    }
  ])

  property_test(
    "array generation with additionalItems as schema and array of items should work",
    %{
      "type" => "array",
      "items" => [%{"type" => "integer"}, %{"type" => "string"}],
      "additionalItems" => %{"type" => "object"}
    }
  )

  property_test("array generation with all options should work", %{
    "items" => %{"type" => "integer"},
    "type" => "array",
    "minItems" => 5,
    "maxItems" => 8,
    "uniqueItems" => true
  })

  property_test("empty objects and arrays generation should work", [
    %{"type" => "object"},
    %{"type" => "array"}
  ])

  property_test("oneOf generation should work", [
    %{"oneOf" => [%{"type" => "integer"}, %{"type" => "boolean"}]},
    %{"oneOf" => [%{"type" => "integer"}, @complex_object], "components" => @components}
  ])

  property_test("anyOf generation should work", [
    %{"anyOf" => [%{"type" => "integer"}, %{"type" => "boolean"}]},
    %{"anyOf" => [%{"type" => "integer"}, @complex_object], "components" => @components}
  ])

  property_test("array of types generation should work", [
    %{"type" => ["integer", "null"], "minimum" => 10},
    %{"type" => ["integer", "string"], "maximum" => 10, "minLength" => 10}
  ])

  property_test("allOf generation should work", [
    %{"allOf" => [%{"type" => "integer"}, %{"type" => "integer", "minimum" => 10}]},
    %{
      "allOf" => [
        %{"type" => "string", "maxLength" => 4},
        %{"type" => "string", "minLength" => 2}
      ]
    },
    %{
      "allOf" => [
        %{"type" => "object", "properties" => %{"foo" => %{"type" => "string"}}},
        %{
          "type" => "object",
          "required" => ["bar"],
          "properties" => %{"bar" => %{"type" => "boolean"}}
        }
      ]
    }
  ])

  property_test("allOf generation with merged values should work", [
    %{
      "allOf" => [
        %{"type" => "integer", "minimum" => 12, "maximum" => 18, "multipleOf" => 3},
        %{"type" => "integer", "minimum" => 10, "maximum" => 20, "multipleOf" => 2}
      ]
    },
    %{
      "allOf" => [
        %{"type" => "string", "maxLength" => 4, "minLength" => 2},
        %{"type" => "string", "maxLength" => 7, "minLength" => 3}
      ]
    },
    %{
      "allOf" => [
        %{
          "type" => "object",
          "required" => ["bar"],
          "properties" => %{
            "bar" => %{"type" => "string"},
            "foo" => %{"type" => "string", "enum" => ["a", "b", "c"]}
          }
        },
        %{
          "type" => "object",
          "required" => ["foo"],
          "properties" => %{"foo" => %{"type" => "string", "enum" => ["b", "c", "d"]}}
        }
      ]
    }
  ])

  property_test("allOf generation with refs should work", [
    %{
      "allOf" => [
        %{"$ref" => "#/components/schemas/Obj1"},
        %{
          "type" => "object",
          "required" => ["foo"],
          "properties" => %{"foo" => %{"type" => "string", "enum" => ["b", "c", "d"]}}
        }
      ],
      "components" => %{
        "schemas" => %{
          "Obj1" => %{
            "type" => "object",
            "required" => ["bar"],
            "properties" => %{
              "bar" => %{"type" => "string"},
              "foo" => %{"type" => "string", "enum" => ["a", "b", "c"]}
            }
          }
        }
      }
    },
    %{
      "allOf" => [
        %{"$ref" => "#/components/schemas/Obj1"},
        %{"$ref" => "#/components/schemas/Obj2"}
      ],
      "components" => %{
        "schemas" => %{
          "Obj1" => %{
            "type" => "object",
            "required" => ["bar"],
            "properties" => %{
              "bar" => %{"type" => "string"},
              "foo" => %{"type" => "string", "enum" => ["a", "b", "c"]}
            }
          },
          "Obj2" => %{
            "type" => "object",
            "required" => ["foo"],
            "properties" => %{"foo" => %{"type" => "string", "enum" => ["b", "c", "d"]}}
          }
        }
      }
    }
  ])

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
