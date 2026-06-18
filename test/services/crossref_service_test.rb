require "test_helper"

class CrossrefServiceTest < ActiveSupport::TestCase
  BODY = {
    message: {
      title: [ "A Great Study" ],
      abstract: "<jats:p>We did <jats:b>things</jats:b>.</jats:p>",
      type: "journal-article",
      publisher: "Pub",
      "container-title": [ "The Journal" ],
      ISSN: [ "1234-5678" ],
      published: { "date-parts": [ [ 2024, 3 ] ] },
      assertion: [
        { name: "received", value: "2024-01-01" },
        { name: "accepted", value: "2024-03-01" }
      ],
      author: [ { given: "Jane", family: "Doe", affiliation: [ { name: "Uni" } ] } ],
      reference: [ { DOI: "10.1/ref1" }, { key: "no-doi" } ],
      "reference-count": 2,
      "is-referenced-by-count": 10,
      DOI: "10.1/x",
      resource: { primary: { URL: "https://pub/x" } }
    }
  }.to_json

  test "parses metadata, strips JATS from the abstract and pulls reference DOIs" do
    stub_request(:get, /api\.crossref\.org\/works\//).to_return(status: 200, body: BODY)
    data = CrossrefService.new("10.1/x").fetch

    assert_equal "A Great Study", data[:title]
    assert_equal "We did things.", data[:abstract]
    assert_equal Date.new(2024, 3, 1), data[:published_date]
    assert_equal Date.new(2024, 1, 1), data[:received_date]
    assert_equal Date.new(2024, 3, 1), data[:accepted_date]
    assert_equal "Jane Doe", data[:authors].first[:name]
    assert_equal [ "10.1/ref1" ], data[:references]
  end

  test "sends the polite-pool mailto" do
    stub = stub_request(:get, %r{api\.crossref\.org/works/.*mailto=})
      .to_return(status: 200, body: BODY)
    CrossrefService.new("10.1/x").fetch
    assert_requested(stub)
  end

  test "returns nil on a non-success response" do
    stub_request(:get, /api\.crossref\.org\/works\//).to_return(status: 404)
    assert_nil CrossrefService.new("10.1/x").fetch
  end
end
