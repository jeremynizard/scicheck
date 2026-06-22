require "test_helper"

class DoiResolverTest < ActiveSupport::TestCase
  test "extracts a raw DOI" do
    assert_equal "10.1097/MS9.0000000000003127",
      DoiResolver.new("10.1097/MS9.0000000000003127").resolve
  end

  test "strips a DOI: prefix" do
    assert_equal "10.1234/abc", DoiResolver.new("DOI: 10.1234/abc").resolve
  end

  test "extracts a DOI from a doi.org URL without any network call" do
    assert_equal "10.1097/ms9.0000000000003127",
      DoiResolver.new("https://doi.org/10.1097/ms9.0000000000003127").resolve
  end

  test "strips trailing punctuation" do
    assert_equal "10.1234/abc", DoiResolver.new("(10.1234/abc).").resolve
  end

  test "returns nil for non-DOI text" do
    assert_nil DoiResolver.new("not a doi").resolve
  end

  test "maps a Nature article URL to its DOI without any network call" do
    assert_equal "10.1038/s41392-020-0207-x",
      DoiResolver.new("https://www.nature.com/articles/s41392-020-0207-x").resolve
  end

  test "maps a Nature URL with query/fragment too" do
    assert_equal "10.1038/nature12373",
      DoiResolver.new("https://www.nature.com/articles/nature12373?foo=bar#sec1").resolve
  end

  test "extracts the DOI from a publisher URL that has it in the path (Springer)" do
    assert_equal "10.1007/s00018-020-03656-y",
      DoiResolver.new("https://link.springer.com/article/10.1007/s00018-020-03656-y").resolve
  end

  test "refuses to fetch a URL that resolves to a private address (SSRF guard)" do
    # No DOI in the path and a private host: must return nil WITHOUT any HTTP.
    assert_nil DoiResolver.new("http://169.254.169.254/article").resolve
  end

  test "scrapes the DOI from a public page's citation meta tag" do
    stub_request(:get, "http://93.184.216.34/article")
      .to_return(status: 200, body: '<meta name="citation_doi" content="10.1234/scraped">')
    assert_equal "10.1234/scraped", DoiResolver.new("http://93.184.216.34/article").resolve
  end

  test "re-checks the host on redirect and refuses one that points to a private address" do
    # A public URL that 301-redirects to the cloud metadata endpoint must not be followed.
    stub_request(:get, "http://93.184.216.34/article")
      .to_return(status: 301, headers: { "Location" => "http://169.254.169.254/latest/meta-data/" })
    assert_nil DoiResolver.new("http://93.184.216.34/article").resolve
    assert_not_requested(:get, "http://169.254.169.254/latest/meta-data/")
  end

  test "follows a public redirect and scrapes the DOI from the destination" do
    stub_request(:get, "http://93.184.216.34/article")
      .to_return(status: 302, headers: { "Location" => "http://8.8.8.8/final" })
    stub_request(:get, "http://8.8.8.8/final")
      .to_return(status: 200, body: '<meta name="citation_doi" content="10.5555/redirected">')
    assert_equal "10.5555/redirected", DoiResolver.new("http://93.184.216.34/article").resolve
  end
end
