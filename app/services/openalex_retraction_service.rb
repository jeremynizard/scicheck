require "net/http"
require "json"

class OpenalexRetractionService
  include HttpClient

  BASE_URL = "https://api.openalex.org/works"
  EMAIL = "contact@scicheck.app"
  BATCH_SIZE = 40

  def initialize(reference_dois)
    @dois = reference_dois || []
  end

  def fetch
    return { retracted_dois: [], checked: 0, retracted_count: 0 } if @dois.empty?

    retracted = []

    @dois.each_slice(BATCH_SIZE) do |batch|
      doi_filter = batch.map { |d| "https://doi.org/#{d}" }.join("|")
      uri = URI("#{BASE_URL}?filter=doi:#{URI.encode_www_form_component(doi_filter)},is_retracted:true&select=doi&per_page=#{BATCH_SIZE}&mailto=#{EMAIL}")

      response = http_get(uri, headers: { "User-Agent" => "SciCheck/1.0 (mailto:#{EMAIL})" })
      next unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      results = data["results"] || []
      results.each do |work|
        retracted << work["doi"]&.gsub("https://doi.org/", "")
      end
    end

    {
      retracted_dois:  retracted.compact,
      checked:         @dois.length,
      retracted_count: retracted.compact.length
    }
  end
end
