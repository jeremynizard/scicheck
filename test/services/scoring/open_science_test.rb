require "test_helper"

class Scoring::OpenScienceTest < ActiveSupport::TestCase
  test "no signals scores zero" do
    s = Scoring::OpenScience.new({ abstract: "A study of things." }, nil, nil).score
    assert_equal 0, s[:level]
    assert_empty s[:detected]
  end

  test "a single registered data bank scores one" do
    s = Scoring::OpenScience.new({ abstract: "" }, { data_banks: [ "ClinicalTrials.gov" ] }, nil).score
    assert_equal 1, s[:level]
    assert_includes s[:detected], "Registered: ClinicalTrials.gov"
  end

  test "data bank plus COI statement scores two" do
    pubmed = { data_banks: [ "Dryad" ], has_coi_statement: true }
    s = Scoring::OpenScience.new({ abstract: "" }, pubmed, nil).score
    assert_equal 2, s[:level]
    assert_includes s[:detected], "Conflict-of-interest statement"
  end

  test "abstract patterns are detected" do
    s = Scoring::OpenScience.new({ abstract: "Code at github.com/foo and data at zenodo.org/bar" }, nil, nil).score
    assert_equal 2, s[:level]
    assert_includes s[:detected], "GitHub"
    assert_includes s[:detected], "Zenodo"
  end

  test "uses OpenAlex abstract when Crossref abstract is missing" do
    s = Scoring::OpenScience.new({ abstract: nil }, nil, { abstract: "Open data shared on osf.io" }).score
    assert_operator s[:level], :>=, 1
    assert_includes s[:detected], "OSF"
  end

  test "does not double count a registry present in both data banks and abstract" do
    pubmed = { data_banks: [ "ClinicalTrials.gov" ] }
    s = Scoring::OpenScience.new({ abstract: "Registered at ClinicalTrials.gov" }, pubmed, nil).score
    assert_equal 1, s[:detected].count { |d| d.include?("ClinicalTrials.gov") }
  end
end
