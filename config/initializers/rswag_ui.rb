Rswag::Ui.configure do |c|
  # List each OpenAPI document that you want to support
  c.openapi_endpoint "/api-docs/v1/swagger.yaml", "API V1 Docs"

  # Optional: disable basic auth for now
  c.basic_auth_enabled = false
end
