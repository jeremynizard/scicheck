require "test_helper"

class AnalysisTest < ActiveSupport::TestCase
  PAYLOAD = {
    doi: "10.1/x",
    result: { global_score: 80, grade: "A", criteria: { study_type: { level: 5, value: "Meta-analysis" } } },
    meta: { title: "T", published: Date.new(2024, 3, 1), authors: [ { name: "Jane", h_index: 30 } ] }
  }.freeze

  test "store denormalizes score/grade and stamps timestamps" do
    a = Analysis.store("10.1/x", "en", PAYLOAD)
    assert_equal 80, a.global_score
    assert_equal "A", a.grade
    assert a.computed_at.present?
  end

  test "payload round-trips with symbol keys and Date preserved" do
    Analysis.store("10.1/x", "en", PAYLOAD)
    a = Analysis.find_by(doi: "10.1/x")
    assert_equal "A", a.result[:grade]                     # symbol keys survive
    assert_equal Date.new(2024, 3, 1), a.meta[:published]  # Date survives (not a String)
    assert_equal "Jane", a.meta[:authors].first[:name]     # nested array-of-hash symbols survive
  end

  test "store upserts — one row per DOI" do
    Analysis.store("10.1/x", "en", PAYLOAD)
    Analysis.store("10.1/x", "en", PAYLOAD.merge(result: { global_score: 50, grade: "C" }))
    assert_equal 1, Analysis.where(doi: "10.1/x").count
    assert_equal 50, Analysis.find_by(doi: "10.1/x").global_score
  end

  test "fresh? reflects the TTL window" do
    a = Analysis.store("10.1/x", "en", PAYLOAD)
    assert a.fresh?
    a.update_column(:computed_at, 2.days.ago)
    assert_not a.fresh?
  end
end
