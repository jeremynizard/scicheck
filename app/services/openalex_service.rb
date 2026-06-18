class OpenalexService
  include HttpClient

  BASE_URL = "https://api.openalex.org/works"

  def initialize(doi)
    @doi = doi.to_s.strip
  end

  def fetch
    return nil if @doi.empty?

    uri  = URI("#{BASE_URL}/https://doi.org/#{URI.encode_www_form_component(@doi)}?mailto=#{Scicheck::Config::CONTACT_EMAIL}")
    data = get_json(uri)
    return nil unless data

    source = data.dig("primary_location", "source") || {}

    {
      openalex_id:       data["id"],
      pmid:              extract_pmid(data.dig("ids", "pmid")),
      type:              data["type"],          # ex: "review", "article", "preprint"
      publication_year:  data["publication_year"],
      publication_date:  data["publication_date"],
      language:          data["language"],
      is_oa:             data.dig("open_access", "is_oa"),
      oa_status:         data.dig("open_access", "oa_status"),
      cited_by_count:    data["cited_by_count"],
      cited_by_percentile_year: data.dig("cited_by_percentile_year", "min"),
      indexed_in:        data["indexed_in"],    # ["crossref", "pubmed", "doaj", ...]
      is_retracted:      data["is_retracted"],  # the analyzed work is itself retracted

      # Source = the journal
      journal_name:      source["display_name"],
      journal_issn:      source["issn_l"],
      is_in_doaj:        source["is_in_doaj"],
      is_core:           source["is_core"],     # indexed in major databases (Scopus, etc.)
      host_organization: source["host_organization_name"],

      # Enriched author data
      authorships:       extract_authorships(data["authorships"]),

      # Article concepts/topics
      topics:            extract_topics(data["topics"]),

      # Abstract reconstructed from OpenAlex's inverted index — a fallback for
      # when Crossref has no abstract deposited (very common).
      abstract:          reconstruct_abstract(data["abstract_inverted_index"]),

      # Link to the open-access version
      oa_url:            data.dig("open_access", "oa_url")
    }
  end

  private

  # OpenAlex stores pmid as a URL like "https://pubmed.ncbi.nlm.nih.gov/40212156".
  def extract_pmid(pmid_url)
    return nil if pmid_url.to_s.empty?
    pmid_url[%r{(\d+)\z}, 1]
  end

  def extract_authorships(authorships)
    return [] unless authorships
    authorships.map do |a|
      {
        name:         a.dig("author", "display_name"),
        openalex_id:  a.dig("author", "id"),
        institutions: a["institutions"]&.map { |i| i["display_name"] } || []
      }
    end
  end

  def extract_topics(topics)
    return [] unless topics
    topics.first(3).map { |t| t["display_name"] }
  end

  # The inverted index maps each word to the positions where it occurs.
  # We rebuild the running text from it.
  def reconstruct_abstract(inverted_index)
    return nil if inverted_index.nil? || inverted_index.empty?

    words = []
    inverted_index.each do |word, positions|
      positions.each { |pos| words[pos] = word }
    end
    text = words.compact.join(" ").strip
    text.empty? ? nil : text
  end
end
