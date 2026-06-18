require "test_helper"

class Scoring::StudyTypeTest < ActiveSupport::TestCase
  def pubmed(types)
    { publication_types: types }
  end

  test "meta-analysis from PubMed scores the top level" do
    s = Scoring::StudyType.new({ type: "review" }, nil, pubmed([ "Journal Article", "Meta-Analysis" ])).score
    assert_equal 5, s[:level]
    assert_equal "Meta-analysis", s[:value]
    assert_equal "PubMed publication type", s[:source_note]
  end

  test "systematic review is distinguished from a narrative review" do
    s = Scoring::StudyType.new({ type: "review" }, nil, pubmed([ "Systematic Review" ])).score
    assert_equal 5, s[:level]
  end

  test "randomized controlled trial scores level 4" do
    s = Scoring::StudyType.new(nil, nil, pubmed([ "Randomized Controlled Trial", "Journal Article" ])).score
    assert_equal 4, s[:level]
  end

  test "clinical trial with a phase suffix is recognized" do
    s = Scoring::StudyType.new(nil, nil, pubmed([ "Clinical Trial, Phase III" ])).score
    assert_equal 3, s[:level]
  end

  test "case report scores low" do
    s = Scoring::StudyType.new(nil, nil, pubmed([ "Case Reports" ])).score
    assert_equal 1, s[:level]
  end

  test "strongest evidence wins when several types are present" do
    s = Scoring::StudyType.new(nil, nil, pubmed([ "Editorial", "Meta-Analysis", "Journal Article" ])).score
    assert_equal 5, s[:level]
  end

  test "PubMed-indexed generic article falls to original article" do
    s = Scoring::StudyType.new(nil, nil, pubmed([ "Journal Article" ])).score
    assert_equal 2, s[:level]
    assert_equal "Original article", s[:value]
  end

  test "preprint via OpenAlex type scores zero" do
    s = Scoring::StudyType.new({ type: "preprint" }, nil, nil).score
    assert_equal 0, s[:level]
  end

  test "preprint via DOI prefix scores zero even without OpenAlex type" do
    s = Scoring::StudyType.new(nil, { doi: "10.1101/2024.01.01.123456" }, nil).score
    assert_equal 0, s[:level]
  end

  test "arXiv DOI prefix is detected as a preprint" do
    s = Scoring::StudyType.new(nil, { doi: "10.48550/arXiv.2401.00001" }, nil).score
    assert_equal 0, s[:level]
  end

  test "refines a generic journal article into a cohort study via MeSH headings" do
    pm = { publication_types: [ "Journal Article" ], mesh_terms: [ "Humans", "Cohort Studies" ] }
    s = Scoring::StudyType.new(nil, nil, pm).score
    assert_equal 3, s[:level]
    assert_equal "Cohort study", s[:value]
    assert_equal "PubMed MeSH heading", s[:source_note]
  end

  test "case-control study from MeSH scores level 2" do
    pm = { publication_types: [ "Journal Article" ], mesh_terms: [ "Case-Control Studies" ] }
    assert_equal 2, Scoring::StudyType.new(nil, nil, pm).score[:level]
  end

  test "a specific publication type is not overridden by MeSH headings" do
    pm = { publication_types: [ "Randomized Controlled Trial" ], mesh_terms: [ "Cohort Studies" ] }
    assert_equal 4, Scoring::StudyType.new(nil, nil, pm).score[:level]
  end

  test "PubMed record with only generic type and no design MeSH stays original article" do
    pm = { publication_types: [ "Journal Article" ], mesh_terms: [ "Humans" ] }
    s = Scoring::StudyType.new(nil, nil, pm).score
    assert_equal 2, s[:level]
    assert_equal "Original article", s[:value]
  end

  test "falls back to OpenAlex review when no PubMed data" do
    s = Scoring::StudyType.new({ type: "review" }, nil, nil).score
    assert_equal 2, s[:level]
    assert_equal "Narrative review", s[:value]
  end

  test "falls back to Crossref journal-article" do
    s = Scoring::StudyType.new(nil, { type: "journal-article" }, nil).score
    assert_equal 2, s[:level]
    assert_equal "Crossref type", s[:source_note]
  end

  test "max_level is always 5" do
    s = Scoring::StudyType.new(nil, nil, nil).score
    assert_equal 5, s[:max_level]
  end
end
