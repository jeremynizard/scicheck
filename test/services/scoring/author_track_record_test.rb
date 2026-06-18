require "test_helper"

class Scoring::AuthorTrackRecordTest < ActiveSupport::TestCase
  def profile(h, institutions = [ "Uni" ])
    { h_index: h, institutions: institutions }
  end

  test "empty profiles are unavailable" do
    assert_nil Scoring::AuthorTrackRecord.new([]).score[:level]
    assert_nil Scoring::AuthorTrackRecord.new(nil).score[:level]
  end

  test "established and affiliated author scores top level" do
    s = Scoring::AuthorTrackRecord.new([ profile(25), profile(8) ]).score
    assert_equal 3, s[:level]
    assert_includes s[:value], "25"
  end

  test "experienced or fully affiliated scores level 2" do
    assert_equal 2, Scoring::AuthorTrackRecord.new([ profile(12, []) ]).score[:level]
    assert_equal 2, Scoring::AuthorTrackRecord.new([ profile(4), profile(2) ]).score[:level]
  end

  test "few publications scores level 1" do
    s = Scoring::AuthorTrackRecord.new([ profile(4, []) ]).score
    assert_equal 1, s[:level]
  end

  test "no track record scores zero" do
    s = Scoring::AuthorTrackRecord.new([ profile(0, []) ]).score
    assert_equal 0, s[:level]
  end
end
