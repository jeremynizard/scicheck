require "test_helper"

class Scoring::CitationProfileTest < ActiveSupport::TestCase
  def data(percentile, year: 2020)
    { cited_by_percentile_year: percentile, publication_year: year }
  end

  test "nil data is unavailable" do
    assert_nil Scoring::CitationProfile.new(nil).score[:level]
  end

  test "nil percentile is treated as too recent" do
    s = Scoring::CitationProfile.new(data(nil)).score
    assert_nil s[:level]
    assert_equal "Too recent", s[:value]
  end

  test "an article from the current year is too recent to score" do
    s = Scoring::CitationProfile.new(data(90, year: Date.today.year)).score
    assert_nil s[:level]
  end

  test "high percentile scores top level" do
    assert_equal 3, Scoring::CitationProfile.new(data(90)).score[:level]
  end

  test "percentile buckets" do
    assert_equal 2, Scoring::CitationProfile.new(data(60)).score[:level]
    assert_equal 1, Scoring::CitationProfile.new(data(30)).score[:level]
    assert_equal 0, Scoring::CitationProfile.new(data(10)).score[:level]
  end
end
