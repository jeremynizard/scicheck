require "net/http"
require "json"

class OpenalexAuthorService
  include HttpClient

  BASE_URL = "https://api.openalex.org/authors"
  EMAIL = "contact@scicheck.app"
  MAX_AUTHORS = 5
  THREAD_TIMEOUT = 3

  def initialize(authorships)
    @authorships = (authorships || []).first(MAX_AUTHORS)
  end

  def fetch
    return [] if @authorships.empty?

    profiles = []
    mutex = Mutex.new

    threads = @authorships.filter_map do |author|
      openalex_id = author[:openalex_id]
      next unless openalex_id

      Thread.new do
        profile = fetch_author(openalex_id, author[:name])
        mutex.synchronize { profiles << profile } if profile
      end
    end

    threads.each { |t| t.join(THREAD_TIMEOUT) }
    profiles
  end

  private

  def fetch_author(openalex_id, name)
    # openalex_id is a full URL like "https://openalex.org/A1234"
    id = openalex_id.split("/").last
    uri = URI("#{BASE_URL}/#{id}?mailto=#{EMAIL}")
    response = http_get(uri, headers: { "User-Agent" => "SciCheck/1.0 (mailto:#{EMAIL})" })
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)

    {
      name:         name || data["display_name"],
      h_index:      data.dig("summary_stats", "h_index"),
      works_count:  data["works_count"],
      institutions: extract_institutions(data["affiliations"])
    }
  rescue StandardError
    nil
  end

  def extract_institutions(affiliations)
    return [] unless affiliations
    affiliations.filter_map { |a| a.dig("institution", "display_name") }.uniq.first(3)
  end
end
