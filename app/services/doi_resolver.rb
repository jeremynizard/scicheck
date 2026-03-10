class DoiResolver
  include HttpClient

  DOI_PATTERN = %r{(10\.\d{4,9}/[^\s"'<>]+)}

  def initialize(input)
    @input = input.to_s.strip
  end

  # Returns a clean DOI string or nil if none could be resolved.
  def resolve
    # 1. Try to extract a DOI pattern directly from the input
    doi = extract_doi(@input)
    return doi if doi

    # 2. If input looks like a URL, fetch it and look for DOI in meta tags
    if @input.match?(%r{\Ahttps?://}i)
      doi = extract_doi_from_url(@input)
      return doi if doi
    end

    # 3. Strip common prefixes as last resort
    cleaned = @input.gsub(/\ADOI:\s*/i, "").strip
    extract_doi(cleaned) || cleaned
  end

  private

  def extract_doi(text)
    match = text.match(DOI_PATTERN)
    return nil unless match

    # Strip trailing punctuation that isn't part of the DOI
    match[1].gsub(/[.,;)\]}>]+\z/, "")
  end

  def extract_doi_from_url(url)
    uri = URI.parse(url)
    response = http_get(uri, headers: { "Accept" => "text/html" })

    # Follow redirects (up to 3)
    3.times do
      break unless response.is_a?(Net::HTTPRedirection)

      location = response["location"]
      # If redirected to doi.org, extract DOI from the URL
      doi = extract_doi(location)
      return doi if doi

      uri = URI.parse(location)
      response = http_get(uri, headers: { "Accept" => "text/html" })
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    body = response.body.to_s

    # Look for DOI in common meta tags
    meta_patterns = [
      /citation_doi["']\s+content=["']([^"']+)/i,
      /DC\.identifier["']\s+content=["']([^"']+)/i,
      /prism\.doi["']\s+content=["']([^"']+)/i,
      /doi["']\s*:\s*["']([^"']+)/i
    ]

    meta_patterns.each do |pattern|
      match = body.match(pattern)
      return extract_doi(match[1]) || match[1].strip if match
    end

    # Fallback: find any DOI pattern in the page
    extract_doi(body)
  rescue URI::InvalidURIError, SocketError, Errno::ECONNREFUSED, Net::OpenTimeout
    nil
  end
end
