# Thin client for any OpenAI-compatible chat-completions endpoint (Groq by
# default; swap via LLM_BASE_URL / LLM_MODEL). Returns the assistant message
# content as a String, or nil on any failure / when no API key is configured.
#
# Provider-agnostic on purpose: the choice of provider (or self-hosting via a
# local OpenAI-compatible server like Ollama) is a config decision, not code.
# Config is injected so it can be exercised in tests without global state.
class LlmClient
  include HttpClient

  def initialize(api_key:  Scicheck::Config::LLM_API_KEY,
                 base_url: Scicheck::Config::LLM_BASE_URL,
                 model:    Scicheck::Config::LLM_MODEL)
    @api_key  = api_key
    @base_url = base_url
    @model    = model
  end

  def available?
    @api_key.present?
  end

  # messages: [{ role: "system"/"user"/..., content: "..." }, ...]
  def chat(messages, temperature: 0.2, max_tokens: 700, json: false)
    return nil unless available?

    uri  = URI("#{@base_url}/chat/completions")
    body = { model: @model, messages: messages, temperature: temperature, max_tokens: max_tokens }
    body[:response_format] = { type: "json_object" } if json

    data = post_json(uri, body: body, headers: { "Authorization" => "Bearer #{@api_key}" })
    data&.dig("choices", 0, "message", "content")
  end
end
