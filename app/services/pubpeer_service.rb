require "net/http"
require "json"

class PubpeerService
  include HttpClient

  BASE_URL = "https://pubpeer.com/api/publications"

  def initialize(doi)
    @doi = doi.strip
  end

  def fetch
    uri = URI("#{BASE_URL}?doi=#{URI.encode_www_form_component(@doi)}")
    response = http_get(uri, headers: { "Accept" => "application/json" })

    case response
    when Net::HTTPSuccess
      data = JSON.parse(response.body)
      comments = data.dig("data") || []
      {
        has_comments:  comments.any?,
        comment_count: comments.length,
        url:           "https://pubpeer.com/search##{URI.encode_www_form_component(@doi)}"
      }
    when Net::HTTPNotFound
      # 404 = aucun commentaire trouve pour ce DOI
      { has_comments: false, comment_count: 0, url: nil }
    else
      nil
    end
  rescue StandardError
    nil
  end
end
