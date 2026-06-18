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

  test "the home page renders" do
    get new_analysis_path
    assert_response :success
    assert_select "form.doi-form"
  end

  test "a blank DOI is rejected" do
    post analyses_path, params: { doi: "" }
    assert_redirected_to new_analysis_path
    assert_equal "Please enter a valid DOI or article URL (e.g. 10.1097/MS9.0000000000003127).", flash[:alert]
  end

  test "a malformed DOI is rejected" do
    post analyses_path, params: { doi: "not-a-doi" }
    assert_redirected_to new_analysis_path
  end

  test "a valid DOI computes, then redirects to a shareable result URL (PRG)" do
    stub_all
    post analyses_path, params: { doi: "10.1234/x" }

    expected_id = Base64.urlsafe_encode64("10.1234/x", padding: false)
    assert_redirected_to analysis_path(expected_id)

    follow_redirect!
    assert_response :success
    assert_select ".grade-circle"
    assert_select ".article-title", text: "The Journal"
  end

  test "a stored result is served from the DB on later views (durable, no re-query)" do
    stub_all
    post analyses_path, params: { doi: "10.1234/x" }
    assert_equal 1, Analysis.where(doi: "10.1234/x").count

    # Drop every stub: a second view must be served from the DB with zero HTTP.
    WebMock.reset!
    get analysis_path(Base64.urlsafe_encode64("10.1234/x", padding: false))
    assert_response :success
    assert_select ".grade-circle"
  end

  test "an invalid result id redirects home" do
    get analysis_path("not-base64-doi!!")
    assert_redirected_to new_analysis_path
  end

  test "an unknown DOI redirects home with an alert" do
    stub_request(:get, /api\.crossref\.org/).to_return(status: 404)
    stub_request(:get, /api\.openalex\.org/).to_return(status: 404)
    stub_request(:get, /pubpeer\.com/).to_return(status: 404)
    post analyses_path, params: { doi: "10.9999/nope" }
    assert_redirected_to new_analysis_path
    assert_match(/not found/i, flash[:alert])
  end
end
