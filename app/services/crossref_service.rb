class CrossrefService
  include HttpClient

  BASE_URL = "https://api.crossref.org/works"

  def initialize(doi)
    @doi = doi.to_s.strip
  end

  def fetch
    return nil if @doi.empty?

    # mailto in the query string puts us in Crossref's "polite pool".
    uri  = URI("#{BASE_URL}/#{URI.encode_www_form_component(@doi)}?mailto=#{Scicheck::Config::CONTACT_EMAIL}")
    data = get_json(uri)&.dig("message")
    return nil unless data

    {
      title:           data.dig("title", 0),
      abstract:        clean_abstract(data["abstract"]),
      type:            data["type"],
      publisher:       data["publisher"],
      journal:         data.dig("container-title", 0),
      issn:            data.dig("ISSN", 0),
      published_date:  extract_date(data["published"]),
      received_date:   extract_assertion(data, "received"),
      accepted_date:   extract_assertion(data, "accepted"),
      authors:         extract_authors(data["author"]),
      references:      extract_references(data["reference"]),
      reference_count: data["reference-count"],
      citation_count:  data["is-referenced-by-count"],
      doi:             data["DOI"],
      url:             data.dig("resource", "primary", "URL")
    }
  end

  private

  def extract_date(date_hash)
    parts = date_hash&.dig("date-parts", 0)
    return nil unless parts&.any?
    Date.new(*parts.fill(1, parts.length...3)) rescue nil
  end

  def extract_assertion(data, name)
    entry = data["assertion"]&.find { |a| a["name"] == name }
    return nil unless entry
    Date.parse(entry["value"]) rescue nil
  end

  def extract_authors(authors)
    return [] unless authors
    authors.map do |a|
      {
        name:        "#{a['given']} #{a['family']}".strip,
        affiliation: a.dig("affiliation", 0, "name")
      }
    end
  end

  def extract_references(refs)
    return [] unless refs
    refs.filter_map { |r| r["DOI"] }
  end

  # Crossref wraps abstracts in JATS XML tags — we strip them.
  def clean_abstract(text)
    text&.gsub(/<[^>]+>/, "")&.strip
  end
end
