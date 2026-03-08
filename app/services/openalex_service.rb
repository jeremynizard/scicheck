require "net/http"
require "json"

class OpenalexService
  include HttpClient

  BASE_URL = "https://api.openalex.org/works"
  EMAIL = "contact@scicheck.app"

  def initialize(doi)
    @doi = doi.strip
  end

  def fetch
    uri = URI("#{BASE_URL}/https://doi.org/#{URI.encode_www_form_component(@doi)}")
    response = http_get(uri, headers: { "User-Agent" => "SciCheck/1.0 (mailto:#{EMAIL})" })
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    return nil unless data

    source = data.dig("primary_location", "source") || {}

    {
      openalex_id:       data["id"],
      type:              data["type"],          # ex: "review", "article", "preprint"
      publication_year:  data["publication_year"],
      publication_date:  data["publication_date"],
      language:          data["language"],
      is_oa:             data.dig("open_access", "is_oa"),
      oa_status:         data.dig("open_access", "oa_status"),
      cited_by_count:    data["cited_by_count"],
      cited_by_percentile_year: data.dig("cited_by_percentile_year", "min"),
      indexed_in:        data["indexed_in"],    # ["crossref", "pubmed", "doaj", ...]

      # Source = la revue
      journal_name:      source["display_name"],
      journal_issn:      source["issn_l"],
      is_in_doaj:        source["is_in_doaj"],
      is_core:           source["is_core"],     # indexé dans les grandes bases (Scopus, etc.)
      host_organization: source["host_organization_name"],

      # Données auteurs enrichies
      authorships:       extract_authorships(data["authorships"]),

      # Concepts/sujets de l'article
      topics:            extract_topics(data["topics"]),

      # Lien vers version open access
      oa_url:            data.dig("open_access", "oa_url")
    }
  end

  private

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
end
