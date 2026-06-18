require "test_helper"

class Scoring::PubpeerCheckTest < ActiveSupport::TestCase
  test "nil data is unavailable" do
    s = Scoring::PubpeerCheck.new(nil).score
    assert_nil s[:level]
  end

  test "no comments scores the safe level" do
    s = Scoring::PubpeerCheck.new({ has_comments: false, comment_count: 0 }).score
    assert_equal 1, s[:level]
    assert_equal "green", s[:color]
    assert_equal 0, s[:comment_count]
  end

  test "a couple of comments flag the article but stay orange" do
    s = Scoring::PubpeerCheck.new({ has_comments: true, comment_count: 2, url: "u" }).score
    assert_equal 0, s[:level]
    assert_equal "orange", s[:color]
    assert_equal 2, s[:comment_count]
    assert_equal "u", s[:pubpeer_url]
  end

  test "many comments turn red" do
    s = Scoring::PubpeerCheck.new({ has_comments: true, comment_count: 5, url: "u" }).score
    assert_equal "red", s[:color]
    assert_equal 5, s[:comment_count]
  end
end
