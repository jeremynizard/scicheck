require "test_helper"

class OpenalexRetractionServiceTest < ActiveSupport::TestCase
  test "no references makes no HTTP call and reports nothing checked" do
    out = OpenalexRetractionService.new([]).fetch
    assert_equal 0, out[:checked]
    assert_equal 0, out[:retracted_count]
  end

  test "flags retracted references returned by OpenAlex" do
    stub_request(:get, %r{api\.openalex\.org/works\?filter})
      .to_return(status: 200, body: { results: [ { doi: "https://doi.org/10.1/bad" } ] }.to_json)

    out = OpenalexRetractionService.new([ "10.1/bad", "10.1/good" ]).fetch
    assert_equal 2, out[:checked]
    assert_equal 1, out[:retracted_count]
    assert_equal [ "10.1/bad" ], out[:retracted_dois]
  end

  test "an upstream failure on a batch is skipped, not fatal" do
    stub_request(:get, %r{api\.openalex\.org/works\?filter}).to_return(status: 500)
    out = OpenalexRetractionService.new([ "10.1/x" ]).fetch
    assert_equal 1, out[:checked]
    assert_equal 0, out[:retracted_count]
  end

  test "de-duplicates input DOIs" do
    stub_request(:get, %r{api\.openalex\.org/works\?filter})
      .to_return(status: 200, body: { results: [] }.to_json)
    out = OpenalexRetractionService.new([ "10.1/x", "10.1/x" ]).fetch
    assert_equal 1, out[:checked]
  end
end
