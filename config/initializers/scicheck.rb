# Central configuration for SciCheck.
#
# All external-API politeness settings live here so they are not duplicated
# across services. Override via environment variables in production.
module Scicheck
  module Config
    # Contact email sent to Crossref / OpenAlex / NCBI "polite pools".
    # A real, monitored address means our traffic is deprioritised for blocking.
    CONTACT_EMAIL = ENV.fetch("SCICHECK_CONTACT_EMAIL", "contact@scicheck.app").freeze

    # Optional NCBI E-utilities API key. Without it we are limited to 3 req/s;
    # with it, 10 req/s. https://www.ncbi.nlm.nih.gov/account/settings/
    NCBI_API_KEY = ENV["NCBI_API_KEY"].freeze

    # User-Agent used for every outbound request.
    USER_AGENT = "SciCheck/1.0 (+https://scicheck.app; mailto:#{CONTACT_EMAIL})".freeze

    # How long a computed analysis is cached (and a result URL stays "warm").
    ANALYSIS_CACHE_TTL = Integer(ENV.fetch("SCICHECK_ANALYSIS_CACHE_TTL", 12 * 60 * 60))

    # Outbound HTTP timeouts (seconds).
    HTTP_OPEN_TIMEOUT = Integer(ENV.fetch("SCICHECK_HTTP_OPEN_TIMEOUT", 5))
    HTTP_READ_TIMEOUT = Integer(ENV.fetch("SCICHECK_HTTP_READ_TIMEOUT", 12))
  end
end
