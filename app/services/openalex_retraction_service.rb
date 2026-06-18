class OpenalexRetractionService
  include HttpClient

  BASE_URL   = "https://api.openalex.org/works"
  BATCH_SIZE = 40

  def initialize(reference_dois)
    @dois = (reference_dois || []).compact.uniq
  end

  def fetch
    return empty_result if @dois.empty?

    retracted = []

    @dois.each_slice(BATCH_SIZE) do |batch|
      doi_filter = batch.map { |d| "https://doi.org/#{d}" }.join("|")
      uri = URI(
        "#{BASE_URL}?filter=doi:#{URI.encode_www_form_component(doi_filter)},is_retracted:true" \
        "&select=doi&per_page=#{BATCH_SIZE}&mailto=#{Scicheck::Config::CONTACT_EMAIL}"
      )

      data = get_json(uri)
      next unless data

      (data["results"] || []).each do |work|
        retracted << work["doi"]&.gsub("https://doi.org/", "")
      end
    end

    {
      retracted_dois:  retracted.compact,
      checked:         @dois.length,
      retracted_count: retracted.compact.length
    }
  end

  private

  def empty_result
    { retracted_dois: [], checked: 0, retracted_count: 0 }
  end
end
