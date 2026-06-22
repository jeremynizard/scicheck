require "test_helper"

class AnalysisRunnerTest < ActiveSupport::TestCase
  def stub_all(openalex_status: 200, crossref_status: 404)
    openalex_work = {
      id: "https://openalex.org/W1",
      ids: { pmid: "https://pubmed.ncbi.nlm.nih.gov/123" },
      type: "review",
      publication_year: 2022,
      is_retracted: false,
      open_access: { oa_status: "gold" },
      cited_by_percentile_year: { min: 80 },
      indexed_in: [ "crossref", "pubmed" ],
      primary_location: { source: { display_name: "J", is_in_doaj: true, is_core: true } },
      authorships: [ { author: { display_name: "Jane Doe", id: "https://openalex.org/A1" }, institutions: [ { display_name: "Uni" } ] } ],
      topics: [],
      abstract_inverted_index: { "Study" => [ 0 ] }
    }.to_json

    pubmed_xml = <<~XML
      <PubmedArticleSet><PubmedArticle><MedlineCitation><Article>
      <PublicationTypeList><PublicationType>Meta-Analysis</PublicationType></PublicationTypeList>
      </Article></MedlineCitation></PubmedArticle></PubmedArticleSet>
    XML

    author = { display_name: "Jane Doe", summary_stats: { h_index: 30 }, works_count: 100,
               affiliations: [ { institution: { display_name: "Uni" } } ] }.to_json

    stub_request(:get, /api\.crossref\.org/).to_return(status: crossref_status, body: "{}")
    stub_request(:get, %r{api\.openalex\.org/works/https}).to_return(status: openalex_status, body: openalex_work)
    stub_request(:get, %r{api\.openalex\.org/works\?filter}).to_return(status: 200, body: { results: [] }.to_json)
    stub_request(:get, %r{api\.openalex\.org/authors/}).to_return(status: 200, body: author)
    stub_request(:get, /pubpeer\.com/).to_return(status: 200, body: { data: [] }.to_json)
    stub_request(:get, /efetch\.fcgi/).to_return(status: 200, body: pubmed_xml)
  end

  test "produces a full result and meta for a findable DOI" do
    stub_all
    out = AnalysisRunner.new("10.1/x").call

    assert_equal "10.1/x", out[:doi]
    # Meta-Analysis from PubMed overrides the coarse OpenAlex "review" type.
    assert_equal 5, out[:result][:criteria][:study_type][:level]
    assert_equal "Jane Doe", out[:meta][:authors].first[:name]
    assert_equal 30, out[:meta][:authors].first[:h_index] # matched by OpenAlex id
    assert_equal "Study", out[:meta][:abstract]
    assert_operator out[:result][:global_score], :>, 0
    # The PMID extracted from OpenAlex must be the one queried at PubMed (chaining).
    assert_requested(:get, /efetch\.fcgi.*id=123/)
  end

  test "still produces a result when PubMed is unavailable" do
    stub_all
    stub_request(:get, /efetch\.fcgi/).to_return(status: 404)
    out = AnalysisRunner.new("10.1/x").call
    # Falls back to OpenAlex 'review' type when PubMed has no data.
    assert_equal 2, out[:result][:criteria][:study_type][:level]
    assert_equal "Narrative review", out[:result][:criteria][:study_type][:value]
  end

  test "returns nil when neither Crossref nor OpenAlex has the DOI" do
    stub_all(openalex_status: 404, crossref_status: 404)
    assert_nil AnalysisRunner.new("10.1/missing").call
  end

  test "AI insights are absent when the LLM is disabled (default)" do
    stub_all
    assert_nil AnalysisRunner.new("10.1/x").call[:ai]
  end

  test "falls back to the PubMed abstract when Crossref and OpenAlex have none" do
    work = {
      id: "https://openalex.org/W9", ids: { pmid: "https://pubmed.ncbi.nlm.nih.gov/19239886" },
      type: "review", publication_year: 2009, is_retracted: false, open_access: {},
      cited_by_percentile_year: { min: 99 }, indexed_in: [ "crossref", "pubmed" ],
      primary_location: { source: { display_name: "Cell" } }, authorships: [], topics: []
      # no abstract_inverted_index → OpenAlex abstract is nil
    }.to_json
    pubmed_xml = "<PubmedArticleSet><PubmedArticle><MedlineCitation><Article>" \
                 "<Abstract><AbstractText>An abstract that only PubMed has, long enough to be useful here.</AbstractText></Abstract>" \
                 "</Article></MedlineCitation></PubmedArticle></PubmedArticleSet>"
    stub_request(:get, /api\.crossref\.org/).to_return(status: 404)
    stub_request(:get, %r{api\.openalex\.org/works/https}).to_return(status: 200, body: work)
    stub_request(:get, %r{api\.openalex\.org/works\?filter}).to_return(status: 200, body: { results: [] }.to_json)
    stub_request(:get, %r{api\.openalex\.org/authors/}).to_return(status: 200, body: "{}")
    stub_request(:get, /pubpeer\.com/).to_return(status: 200, body: { data: [] }.to_json)
    stub_request(:get, /efetch\.fcgi/).to_return(status: 200, body: pubmed_xml)

    abstract = AnalysisRunner.new("10.1/x").call[:meta][:abstract]
    assert_includes abstract, "only PubMed has"
  end

  test "flags the article as retracted via Retraction Watch, with the reason and hard cap" do
    stub_all # OpenAlex says is_retracted: false — Retraction Watch is the source here
    RetractedPaper.create!(doi: "10.1/x", nature: "Retraction", reason: "Falsification of Data")

    out = AnalysisRunner.new("10.1/x").call
    assert out[:meta][:retracted]
    assert_equal "Falsification of Data", out[:meta][:retraction][:reason]
    assert_equal 12, out[:result][:global_score] # retracted-article hard cap
  end
end
