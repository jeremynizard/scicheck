# Throttle abusive clients. Each analysis POST fans out to ~6 external APIs, so
# it is the endpoint worth protecting most. Counters live in Rails.cache.
class Rack::Attack
  # Never throttle the health check.
  safelist("allow/health-check") { |req| req.path == "/up" }

  # Expensive endpoint: running a new analysis.
  throttle("analyses/create/ip", limit: 10, period: 60) do |req|
    req.ip if req.post? && req.path == "/analyses"
  end

  # Cheaper (usually a cache hit) but can recompute on a miss.
  throttle("analyses/show/ip", limit: 40, period: 60) do |req|
    req.ip if req.get? && req.path.start_with?("/analyses/")
  end

  # JSON API consumed by the browser extension.
  throttle("api/ip", limit: 30, period: 60) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Coarse overall ceiling per IP.
  throttle("req/ip", limit: 120, period: 60, &:ip)

  self.throttled_responder = lambda do |_request|
    [ 429, { "Content-Type" => "text/plain" }, [ "Too many requests. Please slow down and try again shortly.\n" ] ]
  end
end
