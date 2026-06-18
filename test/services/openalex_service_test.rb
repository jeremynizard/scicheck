require "test_helper"

class OpenalexServiceTest < ActiveSupport::TestCase
  BODY = {
    id: "https://openalex.org/W1",
    ids: { pmid: "https://pubmed.ncbi.nlm.nih.gov/40212156" },
    type: "review",
    publication_year: 2024,
    is_retracted: false,
    open_access: { is_oa: true, oa_status: "diamond", oa_url: "https://oa" },
    cited_by_percentile_year: { min: 97, max: 98 },
    indexed_in: [ "crossref", "pubmed" ],
    primary_location: { source: { display_name: "J", issn_l: "1", is_in_doaj: true, is_core: true } },
    authorships: [ { author: { display_name: "Jane Doe", id: "https://openalex.org/A1" }, institutions: [ { display_name: "Uni" } ] } ],
    topics: [ { display_name: "Cardiology" } ],
    abstract_inverted_index: { "Hello" => [ 0 ], "world" => [ 1 ] }
  }.to_json

  test "extracts the numeric PMID, journal metadata and authorships" do
    stub_request(:get, /api\.openalex\.org\/works\//).to_return(status: 200, body: BODY)
    data = OpenalexService.new("10.1/x").fetch

    assert_equal "40212156", data[:pmid]
    assert_equal 97, data[:cited_by_percentile_year]
    assert data[:is_in_doaj]
    assert_equal "Jane Doe", data[:authorships].first[:name]
    assert_equal "https://openalex.org/A1", data[:authorships].first[:openalex_id]
  end

  test "reconstructs the abstract from the inverted index" do
    stub_request(:get, /api\.openalex\.org\/works\//).to_return(status: 200, body: BODY)
    assert_equal "Hello world", OpenalexService.new("10.1/x").fetch[:abstract]
  end

  test "returns nil when the work is not found" do
    stub_request(:get, /api\.openalex\.org\/works\//).to_return(status: 404)
    assert_nil OpenalexService.new("10.1/x").fetch
  end
end
