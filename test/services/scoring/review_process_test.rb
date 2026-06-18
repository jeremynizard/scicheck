require "test_helper"

class Scoring::ReviewProcessTest < ActiveSupport::TestCase
  def crossref(received, accepted)
    { received_date: received, accepted_date: accepted }
  end

  test "normal duration scores level 3 from Crossref dates" do
    s = Scoring::ReviewProcess.new(crossref(Date.new(2024, 1, 1), Date.new(2024, 4, 1))).score
    assert_equal 3, s[:level]
    assert_equal "Crossref dates", s[:source_note]
    assert_equal 91, s[:days]
  end

  test "very fast review scores zero" do
    s = Scoring::ReviewProcess.new(crossref(Date.new(2024, 1, 1), Date.new(2024, 1, 10))).score
    assert_equal 0, s[:level]
  end

  test "long review scores level 2" do
    s = Scoring::ReviewProcess.new(crossref(Date.new(2024, 1, 1), Date.new(2024, 12, 1))).score
    assert_equal 2, s[:level]
  end

  test "boundary at 21 days" do
    assert_equal 0, Scoring::ReviewProcess.new(crossref(Date.new(2024, 1, 1), Date.new(2024, 1, 21))).score[:level] # 20 days
    assert_equal 1, Scoring::ReviewProcess.new(crossref(Date.new(2024, 1, 1), Date.new(2024, 1, 22))).score[:level] # 21 days
  end

  test "boundary at 60 days" do
    assert_equal 1, Scoring::ReviewProcess.new(crossref(Date.new(2024, 1, 1), Date.new(2024, 2, 29))).score[:level] # 59 days
    assert_equal 3, Scoring::ReviewProcess.new(crossref(Date.new(2024, 1, 1), Date.new(2024, 3, 1))).score[:level]  # 60 days
  end

  test "falls back to PubMed history dates" do
    pubmed = { received_date: Date.new(2024, 1, 1), accepted_date: Date.new(2024, 3, 1) }
    s = Scoring::ReviewProcess.new(nil, pubmed).score
    assert_equal 3, s[:level]
    assert_equal "PubMed history", s[:source_note]
  end

  test "no dates anywhere is unavailable" do
    s = Scoring::ReviewProcess.new(nil, nil).score
    assert_nil s[:level]
    assert_equal "gray", s[:color]
  end

  test "inconsistent (negative) duration is treated as unavailable" do
    s = Scoring::ReviewProcess.new(crossref(Date.new(2024, 5, 1), Date.new(2024, 1, 1))).score
    assert_nil s[:level]
  end
end
