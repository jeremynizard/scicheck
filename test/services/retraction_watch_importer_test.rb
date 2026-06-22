require "test_helper"

class RetractionWatchImporterTest < ActiveSupport::TestCase
  CSV_DATA = <<~CSV
    Title,OriginalPaperDOI,RetractionNature,Reason,RetractionDate
    Bad Study,10.1/Retracted,Retraction,+Falsification of Data;+Manipulation of Images;,01/15/2024 0:00
    Honest Fix,10.1/Corrected,Correction,+Error in Analyses;,03/02/2023 0:00
    Missing DOI,,Retraction,+Plagiarism;,05/05/2022 0:00
  CSV

  def import_from(csv)
    importer = RetractionWatchImporter.new
    # Stub the private #read to return our CSV regardless of source.
    importer.define_singleton_method(:read) { |_source| csv }
    importer.import("ignored")
  end

  test "imports rows, skipping those without an original DOI" do
    assert_equal 2, import_from(CSV_DATA)
    assert_equal 2, RetractedPaper.count
  end

  test "normalizes the DOI and cleans the reason" do
    import_from(CSV_DATA)
    paper = RetractedPaper.for("10.1/retracted")
    assert_equal "Retraction", paper.nature
    assert_equal "Falsification of Data, Manipulation of Images", paper.reason
    assert_equal Date.new(2024, 1, 15), paper.retraction_date
  end

  test "is idempotent (upsert by DOI)" do
    import_from(CSV_DATA)
    import_from(CSV_DATA)
    assert_equal 2, RetractedPaper.count
  end

  test "retracted? only counts full retractions" do
    import_from(CSV_DATA)
    assert RetractedPaper.retracted?("10.1/retracted")
    assert_not RetractedPaper.retracted?("10.1/corrected") # a Correction is not a retraction
  end

  test "retracted_dois_among returns the matching retracted DOIs" do
    import_from(CSV_DATA)
    matches = RetractedPaper.retracted_dois_among([ "10.1/retracted", "10.1/corrected", "10.1/clean" ])
    assert_equal [ "10.1/retracted" ], matches
  end

  test "de-duplicates multiple rows for the same DOI, preferring a full retraction" do
    csv = <<~CSV
      Title,OriginalPaperDOI,RetractionNature,Reason,RetractionDate
      Paper X,10.1/Dup,Correction,+Minor error;,01/01/2023 0:00
      Paper X,10.1/Dup,Retraction,+Fabrication;,02/01/2024 0:00
    CSV
    assert_equal 1, import_from(csv)
    assert_equal 1, RetractedPaper.where(doi: "10.1/dup").count
    assert_equal "Retraction", RetractedPaper.for("10.1/dup").nature
    assert_equal "Fabrication", RetractedPaper.for("10.1/dup").reason
  end

  test "a later correction does not overwrite a retraction for the same DOI" do
    csv = <<~CSV
      Title,OriginalPaperDOI,RetractionNature,Reason,RetractionDate
      Paper X,10.1/Dup,Retraction,+Fabrication;,02/01/2024 0:00
      Paper X,10.1/Dup,Correction,+Minor error;,03/01/2024 0:00
    CSV
    import_from(csv)
    assert_equal "Retraction", RetractedPaper.for("10.1/dup").nature
  end
end
