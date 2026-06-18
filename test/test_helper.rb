ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# No external HTTP in the test suite — every call must be stubbed.
WebMock.disable_net_connect!(allow_localhost: true)

# Throttling counters would otherwise leak across tests (and the null cache
# store can't increment); rate limiting is exercised in production, not here.
Rack::Attack.enabled = false

module ActiveSupport
  class TestCase
    # Helper to read a fixture file from test/fixtures/files.
    def file_fixture_body(name)
      File.read(Rails.root.join("test", "fixtures", "files", name))
    end
  end
end
