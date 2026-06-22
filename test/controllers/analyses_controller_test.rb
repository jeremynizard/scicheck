require "test_helper"

class AnalysesControllerTest < ActionDispatch::IntegrationTest
  def stub_all
    openalex_work = {
      id: "https://openalex.org/W1",
      ids: { pmid: "https://pubmed.ncbi.nlm.nih.gov/123" },
      type: "review", publication_year: 2022, is_retracted: false,
      open_access: { oa_status: "gold" }, cited_by_percentile_year: { min: 80 },
      indexed_in: [ "crossref", "pubmed" ],
      primary_location: { source: { display_name: "The Journal", is_in_doaj: true, is_core: true } },
      authorships: [ { author: { display_name: "Jane Doe", id: "https://openalex.org/A1" }, institutions: [] } ],
      topics: [], abstract_inverted_index: { "Study" => [ 0 ] }
    }.to_json
    author = { display_name: "Jane Doe", summary_stats: { h_index: 30 }, affiliations: [] }.to_json

    stub_request(:get, /api\.crossref\.org/).to_return(status: 404, body: "{}")
    stub_request(:get, %r{api\.openalex\.org/works/https}).to_return(status: 200, body: openalex_work)
    stub_request(:get, %r{api\.openalex\.org/works\?filter}).to_return(status: 200, body: { results: [] }.to_json)
    stub_request(:get, %r{api\.openalex\.org/authors/}).to_return(status: 200, body: author)
    stub_request(:get, /pubpeer\.com/).to_return(status: 200, body: { data: [] }.to_json)
    stub_request(:get, /efetch\.fcgi/).to_return(status: 404)
  end

  def id_for(doi) = Base64.urlsafe_encode64(doi, padding: false)

  test "the home page renders" do
    get new_analysis_path
    assert_response :success
    assert_select "form.doi-form"
  end

  test "a blank DOI is rejected" do
    post analyses_path, params: { doi: "" }
    assert_redirected_to new_analysis_path
    assert_match(/Couldn't find a DOI/, flash[:alert])
  end

  test "a malformed DOI is rejected" do
    post analyses_path, params: { doi: "not-a-doi" }
    assert_redirected_to new_analysis_path
  end

  test "a valid DOI enqueues the analysis and redirects to a shareable URL (PRG)" do
    assert_enqueued_with(job: AnalysisJob) do
      post analyses_path, params: { doi: "10.1234/x" }
    end
    assert_redirected_to analysis_path(id_for("10.1234/x"))
  end

  test "the result renders once the background job has run" do
    stub_all
    perform_enqueued_jobs { post analyses_path, params: { doi: "10.1234/x" } }
    follow_redirect!
    assert_response :success
    assert_select ".grade-circle"
    assert_select ".article-title", text: "The Journal"
  end

  test "shows a pending page while the analysis is still running" do
    stub_all
    post analyses_path, params: { doi: "10.1234/x" } # enqueued, NOT performed
    follow_redirect!
    assert_response :success
    assert_select ".pending-state"
  end

  test "status reports pending, then ready after the job runs" do
    stub_all
    post analyses_path, params: { doi: "10.1234/x" }

    get analysis_status_path(id_for("10.1234/x"))
    assert_equal "pending", response.parsed_body["state"]

    perform_enqueued_jobs
    get analysis_status_path(id_for("10.1234/x"))
    assert_equal "ready", response.parsed_body["state"]
  end

  test "a stored result is served from the DB on later views (durable, no re-query)" do
    stub_all
    perform_enqueued_jobs { post analyses_path, params: { doi: "10.1234/x" } }
    assert_equal 1, Analysis.where(doi: "10.1234/x").count

    WebMock.reset! # a second view must be served from the DB with zero HTTP
    get analysis_path(id_for("10.1234/x"))
    assert_response :success
    assert_select ".grade-circle"
  end

  test "an invalid result id redirects home" do
    get analysis_path("not-base64-doi!!")
    assert_redirected_to new_analysis_path
  end

  test "an unknown DOI surfaces as not found after the job runs" do
    stub_request(:get, /api\.crossref\.org/).to_return(status: 404)
    stub_request(:get, /api\.openalex\.org/).to_return(status: 404)
    stub_request(:get, /pubpeer\.com/).to_return(status: 404)

    perform_enqueued_jobs { post analyses_path, params: { doi: "10.9999/nope" } }
    get analysis_path(id_for("10.9999/nope"))
    assert_redirected_to new_analysis_path
    assert_match(/not found/i, flash[:alert])
  end
end
