class DoiResolver
  include HttpClient

  DOI_PATTERN = %r{(10\.\d{4,9}/[^\s"'<>]+)}

  # DOI extracted from common publisher HTML meta tags.
  META_PATTERNS = [
    /citation_doi["']\s+content=["']([^"']+)/i,
    /DC\.identifier["']\s+content=["']([^"']+)/i,
    /prism\.doi["']\s+content=["']([^"']+)/i,
    /["']doi["']\s*:\s*["']([^"']+)/i
  ].freeze

  def initialize(input)
    @input = input.to_s.strip
  end

  # Returns a clean DOI string, or nil if none could be resolved.
  def resolve
    # 1. A DOI present directly in the input (raw DOI, "DOI:" prefix, or a
    #    doi.org / publisher URL whose path contains the DOI). No network call.
    doi = extract_doi(@input.sub(/\ADOI:\s*/i, ""))
    return doi if doi

    # 2. The input is a URL with no DOI in the path: fetch it (SSRF-guarded)
    #    and scrape the DOI from its HTML metadata.
    return doi_from_url(@input) if @input.match?(%r{\Ahttps?://}i)

    nil
  end

  private

  def extract_doi(text)
    match = text.match(DOI_PATTERN)
    return nil unless match

    # Strip trailing punctuation that is not part of the DOI.
    match[1].gsub(/[.,;)\]}>]+\z/, "")
  end

  def doi_from_url(url)
    body = safe_http_get_body(url, headers: { "Accept" => "text/html" })
    return nil if body.nil?

    META_PATTERNS.each do |pattern|
      match = body.match(pattern)
      return (extract_doi(match[1]) || clean(match[1])) if match
    end

    # Fallback: any DOI-looking string in the page.
    extract_doi(body)
  end

  def clean(value)
    value.to_s.strip.presence
  end
end
