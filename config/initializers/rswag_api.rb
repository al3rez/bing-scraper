Rswag::Api.configure do |c|
  # Specify the root location where swagger files are located
  c.openapi_root = Rails.root.join('swagger').to_s
end
