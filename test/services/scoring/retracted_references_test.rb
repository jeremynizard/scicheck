require "test_helper"

class Scoring::RetractedReferencesTest < ActiveSupport::TestCase
  test "nil data is unavailable" do
    assert_nil Scoring::RetractedReferences.new(nil).score[:level]
  end

  test "nothing checked is unavailable" do
    s = Scoring::RetractedReferences.new({ checked: 0, retracted_count: 0, retracted_dois: [] }).score
    assert_nil s[:level]
  end

  test "no retracted references scores top level" do
    s = Scoring::RetractedReferences.new({ checked: 30, retracted_count: 0, retracted_dois: [] }).score
    assert_equal 2, s[:level]
  end

  test "one retracted reference scores middle and lists it" do
    s = Scoring::RetractedReferences.new({ checked: 30, retracted_count: 1, retracted_dois: [ "10.1/x" ] }).score
    assert_equal 1, s[:level]
    assert_includes s[:detected], "doi.org/10.1/x"
  end

  test "several retracted references score zero" do
    s = Scoring::RetractedReferences.new({ checked: 30, retracted_count: 3, retracted_dois: %w[a b c] }).score
    assert_equal 0, s[:level]
  end
end
