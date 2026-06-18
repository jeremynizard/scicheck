require "test_helper"

class OpenalexAuthorServiceTest < ActiveSupport::TestCase
  def author_body(h)
    {
      display_name: "Jane Doe",
      summary_stats: { h_index: h },
      works_count: 42,
      affiliations: [ { institution: { display_name: "Uni" } } ]
    }.to_json
  end

  test "no authorships makes no HTTP call" do
    assert_equal [], OpenalexAuthorService.new([]).fetch
    assert_equal [], OpenalexAuthorService.new(nil).fetch
  end

  test "fetches a profile and keeps the OpenAlex id for matching" do
    stub_request(:get, %r{api\.openalex\.org/authors/A1}).to_return(status: 200, body: author_body(30))

    profiles = OpenalexAuthorService.new([ { openalex_id: "https://openalex.org/A1", name: "Jane Doe" } ]).fetch
    assert_equal 1, profiles.size
    p = profiles.first
    assert_equal "https://openalex.org/A1", p[:openalex_id]
    assert_equal 30, p[:h_index]
    assert_equal [ "Uni" ], p[:institutions]
  end

  test "authors without an OpenAlex id are skipped" do
    assert_equal [], OpenalexAuthorService.new([ { name: "No Id" } ]).fetch
  end

  test "a failed author lookup is dropped, not fatal" do
    stub_request(:get, %r{api\.openalex\.org/authors/}).to_return(status: 500)
    profiles = OpenalexAuthorService.new([ { openalex_id: "https://openalex.org/A1", name: "Jane" } ]).fetch
    assert_equal [], profiles
  end
end
