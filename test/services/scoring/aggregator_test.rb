require "test_helper"

class Scoring::AggregatorTest < ActiveSupport::TestCase
  def all_perfect(pubpeer_level: 1, pubpeer_count: 0)
    {
      study_type:           { level: 5, max_level: 5, criterion: "Study type" },
      review_pedigree:      { level: 3, max_level: 3, criterion: "Journal pedigree" },
      review_process:       { level: 3, max_level: 3, criterion: "Review rigor" },
      open_science:         { level: 2, max_level: 2, criterion: "Transparency" },
      pubpeer:              { level: pubpeer_level, max_level: 1, comment_count: pubpeer_count, criterion: "PubPeer" },
      citation_profile:     { level: 3, max_level: 3, criterion: "Citation profile" },
      retracted_references: { level: 2, max_level: 2, criterion: "Retracted references" },
      author_track_record:  { level: 3, max_level: 3, criterion: "Author track record" }
    }
  end

  test "weights sum to exactly 1.0" do
    assert_in_delta 1.0, Scoring::Aggregator::WEIGHTS.values.sum, 1e-9
  end

  test "all-perfect scores yield 100 and grade A" do
    r = Scoring::Aggregator.new(all_perfect).aggregate
    assert_equal 100, r[:global_score]
    assert_equal "A", r[:grade]
    assert_empty r[:notices]
  end

  test "renormalizes over available criteria only" do
    r = Scoring::Aggregator.new({ study_type: { level: 4, max_level: 5, criterion: "Study type" } }).aggregate
    assert_equal 80, r[:global_score] # 4/5 only, weight cancels out
    assert_equal 1, r[:coverage][:counted]
    assert_equal 8, r[:coverage][:total]
    assert_equal 7, r[:coverage][:unavailable].size
    assert_in_delta 0.25, r[:coverage][:weight_used], 1e-9
  end

  test "a couple of PubPeer comments cap the score at 74" do
    r = Scoring::Aggregator.new(all_perfect(pubpeer_level: 0, pubpeer_count: 2)).aggregate
    assert_equal 74, r[:global_score]
    assert_includes r[:notices], :pubpeer
  end

  test "many PubPeer comments cap the score at 59" do
    r = Scoring::Aggregator.new(all_perfect(pubpeer_level: 0, pubpeer_count: 5)).aggregate
    assert_equal 59, r[:global_score]
  end

  test "exactly 3 PubPeer comments triggers the major cap (boundary)" do
    r = Scoring::Aggregator.new(all_perfect(pubpeer_level: 0, pubpeer_count: 3)).aggregate
    assert_equal 59, r[:global_score]
  end

  test "a flag level of 0 with no counted comments does not cap (data inconsistency)" do
    r = Scoring::Aggregator.new(all_perfect(pubpeer_level: 0, pubpeer_count: 0)).aggregate
    assert_equal 90, r[:global_score] # 0/1 pubpeer pulls it to 90, but no cap applied
    assert_empty r[:notices]
  end

  test "a retracted article is hard-capped regardless of other scores" do
    r = Scoring::Aggregator.new(all_perfect, retracted: true).aggregate
    assert_equal 12, r[:global_score]
    assert_equal "E", r[:grade]
    assert_includes r[:notices], :retracted
  end

  test "no available criteria yields zero" do
    r = Scoring::Aggregator.new({}).aggregate
    assert_equal 0, r[:global_score]
    assert_equal 0, r[:coverage][:counted]
  end

  test "grade boundaries" do
    assert_equal "B", Scoring::Aggregator.new({ study_type: { level: 3, max_level: 5 } }).aggregate[:grade] # 60
    assert_equal "C", Scoring::Aggregator.new({ study_type: { level: 2, max_level: 5 } }).aggregate[:grade] # 40
    assert_equal "D", Scoring::Aggregator.new({ study_type: { level: 1, max_level: 5 } }).aggregate[:grade] # 20
  end
end
