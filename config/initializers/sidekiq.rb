# frozen_string_literal: true

require "sidekiq"

sidekiq_redis_url = ENV.fetch("SIDEKIQ_REDIS_URL") do
  ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
end

Sidekiq.configure_server do |config|
  config.redis = {url: sidekiq_redis_url}
end

Sidekiq.configure_client do |config|
  config.redis = {url: sidekiq_redis_url}
end
