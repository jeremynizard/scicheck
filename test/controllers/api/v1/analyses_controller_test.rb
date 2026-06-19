require "test_helper"

module Api
  module V1
    class AnalysesControllerTest < ActionDispatch::IntegrationTest
      def stub_all
        work = {
          id: "https://openalex.org/W1", ids: {}, type: "review", publication_year: 2022,
          is_retracted: false, open_access: { oa_status: "gold" }, cited_by_percentile_year: { min: 80 },
          indexed_in: [ "crossref", "pubmed" ],
          primary_location: { source: { display_name: "The Journal", is_in_doaj: true, is_core: true } },
          authorships: [], topics: [], abstract_inverted_index: { "Study" => [ 0 ] }
        }.to_json
        stub_request(:get, /api\.crossref\.org/).to_return(status: 404)
        stub_request(:get, %r{api\.openalex\.org/works/https}).to_return(status: 200, body: work)
        stub_request(:get, %r{api\.openalex\.org/works\?filter}).to_return(status: 200, body: { results: [] }.to_json)
        stub_request(:get, %r{api\.openalex\.org/authors/}).to_return(status: 200, body: "{}")
        stub_request(:get, /pubpeer\.com/).to_return(status: 200, body: { data: [] }.to_json)
        stub_request(:get, /efetch\.fcgi/).to_return(status: 404)
      end

      test "rejects an invalid DOI" do
        get "/api/v1/analysis", params: { doi: "not-a-doi" }
        assert_response :unprocessable_entity
        assert_equal "invalid_doi", response.parsed_body["error"]
      end

      test "returns pending and enqueues for a cold DOI" do
        stub_all
        get "/api/v1/analysis", params: { doi: "10.1234/x" }
        assert_response :accepted
        assert_equal "pending", response.parsed_body["state"]
        assert response.parsed_body["url"].present?
      end

      test "returns the score once ready" do
        stub_all
        perform_enqueued_jobs { get "/api/v1/analysis", params: { doi: "10.1234/x" } }
        get "/api/v1/analysis", params: { doi: "10.1234/x" }

        assert_response :success
        body = response.parsed_body
        assert_equal "ready", body["state"]
        assert_equal "The Journal", body["title"]
        assert body["grade"].present?
        assert body["criteria"].is_a?(Array)
        assert_operator body["criteria"].size, :>, 0
      end

      test "sends CORS headers so the extension can call it cross-origin" do
        stub_all
        get "/api/v1/analysis", params: { doi: "10.1234/x" }, headers: { "Origin" => "https://pubmed.ncbi.nlm.nih.gov" }
        assert_equal "*", response.headers["Access-Control-Allow-Origin"]
      end
    end
  end
end
