# Optional "AI-assisted" layer. Reads ONLY the abstract and returns a
# plain-language summary + a few qualitative observations, in the user's
# language. Purely informational — it NEVER feeds the deterministic A–E score.
#
# Returns { summary:, points: } or nil (no key, no/short abstract, or any error)
# so the caller can simply hide the block when absent.
class AiInsights
  LANGUAGES     = { "en" => "English", "fr" => "French" }.freeze
  MIN_ABSTRACT  = 80 # chars — below this an abstract is too thin to be useful

  def initialize(meta, locale, client: LlmClient.new)
    @meta   = meta || {}
    @locale = locale.to_s
    @client = client
  end

  def generate
    return nil unless @client.available?

    abstract = @meta[:abstract].to_s.strip
    return nil if abstract.length < MIN_ABSTRACT

    content = @client.chat(messages(abstract), json: true)
    return nil if content.to_s.strip.empty?

    parsed = parse(content)
    return nil unless parsed

    summary = parsed["summary"].to_s.strip
    points  = Array(parsed["points"]).map { |p| p.to_s.strip }.reject(&:empty?).first(6)
    return nil if summary.empty? && points.empty?

    { summary: summary, points: points }
  rescue StandardError => e
    Rails.logger.warn("[AiInsights] #{e.class}: #{e.message}") if defined?(Rails)
    nil
  end

  private

  def parse(content)
    json = JSON.parse(content)
    json.is_a?(Hash) ? json : nil
  rescue JSON::ParserError
    nil
  end

  def language
    LANGUAGES[@locale] || "English"
  end

  def messages(abstract)
    [
      { role: "system", content: system_prompt },
      { role: "user",   content: user_prompt(abstract) }
    ]
  end

  def system_prompt
    "You are a scientific-literacy assistant for the general public. You read ONLY the abstract " \
      "provided and must not invent facts that are not in it. Be accurate, neutral and concise. " \
      "Respond in #{language}. Output ONLY a valid JSON object."
  end

  def user_prompt(abstract)
    <<~PROMPT
      Title: #{@meta[:title]}
      Abstract: #{abstract}

      Return a JSON object with exactly these keys:
      - "summary": 2-3 sentences, plain language — what the study looked at and what it reports.
      - "points": an array of 3-5 short, neutral observations a critical reader should note from the
        abstract (e.g. study-design hints, sample size if stated, whether limitations/uncertainty are
        acknowledged, any over-claiming relative to what is shown, whether funding or conflicts of
        interest are mentioned). If something is not stated in the abstract, say so rather than guessing.
    PROMPT
  end
end
