require "test_helper"

class HttpClientTest < ActiveSupport::TestCase
  class Probe
    include HttpClient
  end

  setup { @client = Probe.new }

  def public?(url)
    @client.public_http_uri?(URI.parse(url))
  end

  test "rejects loopback, private, link-local and metadata addresses" do
    assert_not public?("http://127.0.0.1/")
    assert_not public?("http://10.0.0.5/")
    assert_not public?("http://192.168.1.1/")
    assert_not public?("http://172.16.0.1/")
    assert_not public?("http://169.254.169.254/latest/meta-data/") # cloud metadata
    assert_not public?("http://[::1]/")
  end

  test "rejects non-HTTP schemes" do
    assert_not public?("ftp://8.8.8.8/")
    assert_not public?("file:///etc/passwd")
  end

  test "accepts genuinely public addresses" do
    assert public?("http://8.8.8.8/")
    assert public?("https://1.1.1.1/")
  end

  test "get_json returns nil on a non-success response instead of raising" do
    stub_request(:get, "https://api.example.test/x").to_return(status: 500, body: "boom")
    assert_nil @client.get_json(URI("https://api.example.test/x"))
  end

  test "get_json returns nil on malformed JSON" do
    stub_request(:get, "https://api.example.test/x").to_return(status: 200, body: "not json{")
    assert_nil @client.get_json(URI("https://api.example.test/x"))
  end

  test "get_json parses a successful JSON body" do
    stub_request(:get, "https://api.example.test/x").to_return(status: 200, body: '{"a":1}')
    assert_equal({ "a" => 1 }, @client.get_json(URI("https://api.example.test/x")))
  end

  test "sends a polite User-Agent" do
    stub = stub_request(:get, "https://api.example.test/x")
      .with(headers: { "User-Agent" => Scicheck::Config::USER_AGENT })
      .to_return(status: 200, body: "{}")
    @client.get_json(URI("https://api.example.test/x"))
    assert_requested(stub)
  end
end
