Application.put_env(
  :ex_json_schema,
  :custom_format_validator,
  {JsonDataFakerTest.CustomFormat, :validate}
)

Application.put_env(
  :json_data_faker,
  :custom_format_generator,
  {JsonDataFakerTest.CustomFormat, :generate}
)

ExUnit.start()
