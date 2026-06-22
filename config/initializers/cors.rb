# Allow the browser extension (running on third-party sites like PubMed and
# journal pages) to call the read-only JSON API. No credentials are used, so a
# wildcard origin is safe for this public, GET-only endpoint.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "/api/*", headers: :any, methods: %i[get options]
  end
end
