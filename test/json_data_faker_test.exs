defmodule JsonDataFakerTest.Helpers do
  defmacro property_test(name, schemas, opts \\ []) do
    quote do
      property unquote(name) do
        Enum.each(List.wrap(unquote(schemas)), fn schema ->
          resolved_schema = ExJsonSchema.Schema.resolve(schema)

          check all(data <- JsonDataFaker.generate!(schema, unquote(opts))) do
            assert ExJsonSchema.Validator.valid?(resolved_schema, data)
          end
        end)
      end
    end
  end
end

defmodule JsonDataFakerTest.CustomFormat do
  def generate("foo", _root, _opts) do
    StreamData.string([?a..?f])
  end

  def validate("foo", data) do
    Regex.match?(~r/^[a-f]*$/, data)
  end

  def validate(_, _data), do: true
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

  @schema_keys [
    {"pattern", "[0-9]+"},
    {"minLength", 2},
    {"maxLength", 5},
    {"multipleOf", 3},
    {"maximum", 10},
    {"exclusiveMaximum", true, %{"maximum" => 3}},
    {"minimum", 5},
    {"exclusiveMinimum", false, %{"minimum" => 1}},
    {"additionalItems", true},
    {"items", %{"type" => "integer"}},
    {"maxItems", 7},
    {"minItems", 4},
    {"uniqueItems", true},
    {"maxProperties", 2},
    {"minProperties", 5},
    {"required", ["foo"], %{"properties" => %{"foo" => %{"type" => "string"}}}},
    {"additionalProperties", false},
    {"properties", %{"foo" => %{"type" => "string"}}},
    {"patternProperties", %{"[0-9]+" => %{"type" => "boolean"}}}
  ]

  for tuple <- @schema_keys do
    {key, map} =
      case tuple do
        {key, value, extra} -> {key, Map.merge(%{key => value}, extra)}
        {key, value} -> {key, %{key => value}}
      end

    property_test(
      "generation from schema with single key #{key} should work",
      unquote(Macro.escape(map))
    )
  end

  property "string uuid generation should work" do
    schema = %{"type" => "string", "format" => "uuid"}

    check all(data <- JsonDataFaker.generate!(schema)) do
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

  property_test("string generation with custom format should work", %{
    "type" => "string",
    "format" => "foo"
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

  property_test("require_optional_properties property should work", @full_object,
    require_optional_properties: true
  )

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
      "additionalItems" => false,
      "minItems" => 2
    },
    %{
      "items" => [%{"type" => "integer"}, %{"type" => "string"}],
      "type" => "array",
      "additionalItems" => false,
      "maxItems" => 1
    },
    %{
      "items" => [%{"type" => "integer"}, %{"type" => "string"}],
      "type" => "array",
      "additionalItems" => true
    },
    %{
      "items" => [%{"type" => "integer"}, %{"type" => "string"}],
      "type" => "array",
      "additionalItems" => true,
      "minItems" => 3
    },
    %{
      "items" => [%{"type" => "integer"}, %{"type" => "string"}],
      "type" => "array",
      "additionalItems" => true,
      "maxItems" => 1
    },
    %{
      "items" => [%{"type" => "integer"}, %{"type" => "string"}],
      "type" => "array",
      "additionalItems" => true,
      "maxItems" => 3
    },
    %{
      "items" => [%{"type" => "integer"}, %{"type" => "string"}],
      "type" => "array",
      "additionalItems" => true,
      "maxItems" => 3,
      "minItems" => 1
    }
  ])

  property_test(
    "array generation with additionalItems as schema and array of items should work",
    [
      %{
        "type" => "array",
        "items" => [%{"type" => "integer"}, %{"type" => "string"}],
        "additionalItems" => %{"type" => "object"}
      },
      %{
        "type" => "array",
        "items" => [%{"type" => "integer"}, %{"type" => "string"}],
        "additionalItems" => %{"type" => "object"},
        "minItems" => 1
      },
      %{
        "type" => "array",
        "items" => [%{"type" => "integer"}, %{"type" => "string"}],
        "additionalItems" => %{"type" => "object"},
        "minItems" => 3
      },
      %{
        "type" => "array",
        "items" => [%{"type" => "integer"}, %{"type" => "string"}],
        "additionalItems" => %{"type" => "object"},
        "maxItems" => 1
      },
      %{
        "type" => "array",
        "items" => [%{"type" => "integer"}, %{"type" => "string"}],
        "additionalItems" => %{"type" => "object"},
        "maxItems" => 3
      },
      %{
        "type" => "array",
        "items" => [%{"type" => "integer"}, %{"type" => "string"}],
        "additionalItems" => %{"type" => "object"},
        "maxItems" => 3,
        "minItems" => 1
      }
    ]
  )

  property_test("array generation with all options should work", %{
    "items" => %{"type" => "integer"},
    "type" => "array",
    "minItems" => 5,
    "maxItems" => 8,
    "uniqueItems" => true
  })

  property_test("generation of arrays with small enum of unique items should work", %{
    "type" => "array",
    "uniqueItems" => true,
    "items" => %{
      "type" => "string",
      "enum" => ["a", "b"]
    }
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

  property_test("patternProperties generation should work", %{
    "patternProperties" => %{
      "^[0-9]{4}$" => %{"type" => "integer"},
      "^[a-z]{4}$" => %{"type" => "string"}
    },
    "type" => "object",
    "properties" => %{
      "foo" => %{"type" => "boolean"},
      "bar" => %{"type" => "array", "items" => %{"type" => "integer"}}
    },
    "required" => ["foo"]
  })

  property_test(
    "patternProperties generation with require_optional_properties should work",
    %{
      "patternProperties" => %{
        "^[0-9]{4}$" => %{"type" => "integer"},
        "^[a-z]{4}$" => %{"type" => "string"}
      },
      "type" => "object",
      "properties" => %{
        "foo" => %{"type" => "boolean"},
        "bar" => %{"type" => "array", "items" => %{"type" => "integer"}}
      },
      "required" => ["foo"]
    },
    require_optional_properties: true
  )

  property_test("object generation with min/maxProperties should work", [
    %{
      "properties" => %{
        "bar" => %{"items" => %{"type" => "integer"}, "type" => "array"},
        "foo" => %{"type" => "boolean"}
      },
      "required" => ["foo"],
      "type" => "object",
      "minProperties" => 1
    },
    %{
      "properties" => %{
        "bar" => %{"items" => %{"type" => "integer"}, "type" => "array"},
        "foo" => %{"type" => "boolean"}
      },
      "required" => ["foo"],
      "type" => "object",
      "maxProperties" => 1
    },
    %{
      "properties" => %{
        "bar" => %{"items" => %{"type" => "integer"}, "type" => "array"},
        "foo" => %{"type" => "boolean"}
      },
      "required" => ["foo"],
      "type" => "object",
      "minProperties" => 1,
      "maxProperties" => 2
    }
  ])

  property_test("object generation with min/maxProperties and patternProperties should work", [
    %{
      "patternProperties" => %{
        "^[0-9]{4}$" => %{"type" => "integer"},
        "^[a-z]{4}$" => %{"type" => "string"}
      },
      "properties" => %{
        "bar" => %{"items" => %{"type" => "integer"}, "type" => "array"},
        "foo" => %{"type" => "boolean"}
      },
      "required" => ["foo"],
      "type" => "object",
      "minProperties" => 3
    },
    %{
      "patternProperties" => %{
        "^[0-9]{4}$" => %{"type" => "integer"},
        "^[a-z]{4}$" => %{"type" => "string"}
      },
      "properties" => %{
        "bar" => %{"items" => %{"type" => "integer"}, "type" => "array"},
        "foo" => %{"type" => "boolean"}
      },
      "required" => ["foo"],
      "type" => "object",
      "maxProperties" => 1
    },
    %{
      "patternProperties" => %{
        "^[0-9]{4}$" => %{"type" => "integer"},
        "^[a-z]{4}$" => %{"type" => "string"}
      },
      "properties" => %{
        "bar" => %{"items" => %{"type" => "integer"}, "type" => "array"},
        "foo" => %{"type" => "boolean"}
      },
      "required" => ["foo"],
      "type" => "object",
      "minProperties" => 2,
      "maxProperties" => 4
    }
  ])

  property_test("additionalProperties generation should work", [
    %{
      "additionalProperties" => false,
      "type" => "object",
      "properties" => %{
        "foo" => %{"type" => "boolean"},
        "bar" => %{"type" => "array", "items" => %{"type" => "integer"}}
      },
      "required" => ["foo"]
    },
    %{
      "minProperties" => 3,
      "additionalProperties" => true,
      "type" => "object",
      "properties" => %{
        "foo" => %{"type" => "boolean"},
        "bar" => %{"type" => "array", "items" => %{"type" => "integer"}}
      },
      "required" => ["foo"]
    },
    %{
      "minProperties" => 3,
      "additionalProperties" => %{"type" => "integer"},
      "type" => "object",
      "properties" => %{
        "foo" => %{"type" => "boolean"},
        "bar" => %{"type" => "array", "items" => %{"type" => "integer"}}
      },
      "required" => ["foo"]
    }
  ])

  property_test("additionalProperties generation with patternProperties should work", [
    %{
      "additionalProperties" => false,
      "patternProperties" => %{
        "^[0-9]{4}$" => %{"type" => "integer"},
        "^[a-z]{4}$" => %{"type" => "string"}
      },
      "type" => "object",
      "properties" => %{
        "foo" => %{"type" => "boolean"},
        "bar" => %{"type" => "array", "items" => %{"type" => "integer"}}
      },
      "required" => ["foo"]
    },
    %{
      "minProperties" => 3,
      "additionalProperties" => true,
      "patternProperties" => %{
        "^[0-9]{4}$" => %{"type" => "integer"},
        "^[a-z]{4}$" => %{"type" => "string"}
      },
      "type" => "object",
      "properties" => %{
        "foo" => %{"type" => "boolean"},
        "bar" => %{"type" => "array", "items" => %{"type" => "integer"}}
      },
      "required" => ["foo"]
    },
    %{
      "minProperties" => 3,
      "additionalProperties" => %{"type" => "integer"},
      "patternProperties" => %{
        "^[0-9]{4}$" => %{"type" => "integer"},
        "^[a-z]{4}$" => %{"type" => "string"}
      },
      "type" => "object",
      "properties" => %{
        "foo" => %{"type" => "boolean"},
        "bar" => %{"type" => "array", "items" => %{"type" => "integer"}}
      },
      "required" => ["foo"]
    }
  ])

  property_test("generation from schema with 'not' key should work", %{
    "type" => "integer",
    "minimum" => 0,
    "multipleOf" => 2,
    "not" => %{"multipleOf" => 3}
  })

  test "invalid schema should return error or raise" do
    assert {:error, _} = JsonDataFaker.generate(nil)
    assert {:error, _} = JsonDataFaker.generate([])
    assert {:error, _} = JsonDataFaker.generate(%{"minimum" => "foo"})

    assert_raise JsonDataFaker.InvalidSchemaError, fn ->
      JsonDataFaker.generate!(%{"minimum" => 5, "maximum" => 1})
    end

    assert_raise JsonDataFaker.InvalidSchemaError, fn ->
      JsonDataFaker.generate!(%{"required" => ["a", "b"], "maxProperties" => 1})
    end

    assert_raise JsonDataFaker.InvalidSchemaError, fn ->
      JsonDataFaker.generate!(%{"additionalProperties" => false, "minProperties" => 3})
    end

    assert_raise JsonDataFaker.InvalidSchemaError, fn ->
      JsonDataFaker.generate!(%{
        "additionalItems" => false,
        "items" => [%{"type" => "integer"}],
        "minItems" => 2
      })
    end
  end
end
