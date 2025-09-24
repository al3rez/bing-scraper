# frozen_string_literal: true

require "sidekiq"

sidekiq_redis_url = ENV.fetch("SIDEKIQ_REDIS_URL") do
  ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
end

redis_config = {url: sidekiq_redis_url}

# Add SSL configuration for Heroku Redis
if sidekiq_redis_url.start_with?("rediss://")
  redis_config[:ssl_params] = {verify_mode: OpenSSL::SSL::VERIFY_NONE}
end

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
