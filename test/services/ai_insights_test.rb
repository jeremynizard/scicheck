require "test_helper"

class AiInsightsTest < ActiveSupport::TestCase
  ABSTRACT = "We conducted a randomized controlled trial of 240 patients to assess the effect of the " \
             "intervention on recovery time, with a 12-month follow-up and pre-registered outcomes."

  # Minimal fake LLM client (dependency-injected) — no HTTP, no global state.
  class FakeClient
    def initialize(reply:, available: true)
      @reply = reply
      @available = available
    end

    def available? = @available
    def chat(*) = @reply
  end

  def insights(meta, reply:, available: true)
    AiInsights.new(meta, "en", client: FakeClient.new(reply: reply, available: available)).generate
  end

  test "returns nil when the client is unavailable" do
    assert_nil insights({ abstract: ABSTRACT }, reply: nil, available: false)
  end

  test "returns nil for a too-short abstract" do
    assert_nil insights({ abstract: "tiny" }, reply: "{}")
  end

  test "parses summary and points from the model" do
    reply = { summary: "A trial of 240 patients.", points: [ "RCT design", "n=240 stated" ] }.to_json
    out = insights({ abstract: ABSTRACT, title: "T" }, reply: reply)
    assert_equal "A trial of 240 patients.", out[:summary]
    assert_equal [ "RCT design", "n=240 stated" ], out[:points]
  end

  test "returns nil when the model returns non-JSON" do
    assert_nil insights({ abstract: ABSTRACT }, reply: "not json at all")
  end

  test "returns nil when the model returns empty content" do
    assert_nil insights({ abstract: ABSTRACT }, reply: "")
  end

  test "caps the number of points" do
    reply = { summary: "s", points: (1..20).map { |i| "p#{i}" } }.to_json
    assert_operator insights({ abstract: ABSTRACT }, reply: reply)[:points].size, :<=, 6
  end
end
