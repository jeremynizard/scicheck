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

    # --- Optional "AI-assisted" layer (abstract-only; never affects the score) ---
    # Any OpenAI-compatible chat endpoint. Default points at Groq's free tier
    # running an open-weight model; swap provider/model via ENV with no code change.
    LLM_API_KEY      = ENV["LLM_API_KEY"].freeze
    LLM_BASE_URL     = ENV.fetch("LLM_BASE_URL", "https://api.groq.com/openai/v1").freeze
    # Groq deprecated llama-3.3-70b-versatile (2026-06-17); gpt-oss-120b is a
    # current, JSON-capable replacement. Override per provider via LLM_MODEL.
    LLM_MODEL        = ENV.fetch("LLM_MODEL", "openai/gpt-oss-120b").freeze
    LLM_READ_TIMEOUT = Integer(ENV.fetch("SCICHECK_LLM_READ_TIMEOUT", 25))

    # The AI layer is active only when an API key is configured.
    def self.llm_enabled?
      LLM_API_KEY.present?
    end
  end
end
