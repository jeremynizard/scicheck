class OpenalexAuthorService
  include HttpClient

  BASE_URL       = "https://api.openalex.org/authors"
  MAX_AUTHORS    = 5
  THREAD_TIMEOUT = 6

  def initialize(authorships)
    @authorships = (authorships || []).first(MAX_AUTHORS)
  end

  def fetch
    return [] if @authorships.empty?

    profiles = []
    mutex    = Mutex.new

    threads = @authorships.filter_map do |author|
      openalex_id = author[:openalex_id]
      next unless openalex_id

      Thread.new do
        profile = fetch_author(openalex_id, author[:name])
        mutex.synchronize { profiles << profile } if profile
      end
    end

    # Each request already has its own read/open timeout, so join with a
    # generous ceiling: it bounds the wait without leaving sockets hanging.
    threads.each { |t| t.join(THREAD_TIMEOUT) }
    profiles
  end

  private

  def fetch_author(openalex_id, name)
    # openalex_id is a full URL like "https://openalex.org/A1234".
    id   = openalex_id.split("/").last
    uri  = URI("#{BASE_URL}/#{id}?mailto=#{Scicheck::Config::CONTACT_EMAIL}")
    data = get_json(uri)
    return nil unless data

    {
      openalex_id:  openalex_id,
      name:         name || data["display_name"],
      h_index:      data.dig("summary_stats", "h_index"),
      works_count:  data["works_count"],
      institutions: extract_institutions(data["affiliations"])
    }
  end

  def extract_institutions(affiliations)
    return [] unless affiliations
    affiliations.filter_map { |a| a.dig("institution", "display_name") }.uniq.first(3)
  end
end
