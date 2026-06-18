require "test_helper"

class Scoring::ReviewPedigreeTest < ActiveSupport::TestCase
  def data(is_core:, in_pubmed:, is_in_doaj: false, name: "J")
    indexed = in_pubmed ? [ "crossref", "pubmed" ] : [ "crossref" ]
    { is_core: is_core, indexed_in: indexed, is_in_doaj: is_in_doaj, journal_name: name }
  end

  test "core and PubMed indexed scores top level" do
    s = Scoring::ReviewPedigree.new(data(is_core: true, in_pubmed: true)).score
    assert_equal 3, s[:level]
  end

  test "partially indexed scores level 2" do
    assert_equal 2, Scoring::ReviewPedigree.new(data(is_core: true, in_pubmed: false)).score[:level]
    assert_equal 2, Scoring::ReviewPedigree.new(data(is_core: false, in_pubmed: true)).score[:level]
  end

  test "DOAJ only scores level 1" do
    s = Scoring::ReviewPedigree.new(data(is_core: false, in_pubmed: false, is_in_doaj: true)).score
    assert_equal 1, s[:level]
  end

  test "not indexed scores zero with neutral, non-defamatory language" do
    s = Scoring::ReviewPedigree.new(data(is_core: false, in_pubmed: false)).score
    assert_equal 0, s[:level]
    assert_not_includes s[:explanation].downcase, "predatory"
  end

  test "exposes indexing badges" do
    s = Scoring::ReviewPedigree.new(data(is_core: true, in_pubmed: true, is_in_doaj: true)).score
    labels = s[:badges].map { |b| b[:label] }
    assert_equal %w[PubMed Core DOAJ], labels
    assert s[:badges].all? { |b| b[:present] }
  end
end
