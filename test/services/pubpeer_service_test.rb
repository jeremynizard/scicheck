require "test_helper"

class PubpeerServiceTest < ActiveSupport::TestCase
  test "reports comments when PubPeer returns data" do
    stub_request(:get, /pubpeer\.com/)
      .to_return(status: 200, body: { data: [ {}, {} ] }.to_json)
    out = PubpeerService.new("10.1/x").fetch
    assert out[:has_comments]
    assert_equal 2, out[:comment_count]
    assert out[:url].present?
  end

  test "reports no comments when data is empty" do
    stub_request(:get, /pubpeer\.com/).to_return(status: 200, body: { data: [] }.to_json)
    out = PubpeerService.new("10.1/x").fetch
    assert_not out[:has_comments]
    assert_equal 0, out[:comment_count]
  end

  test "treats a 404 as no comments" do
    stub_request(:get, /pubpeer\.com/).to_return(status: 404)
    out = PubpeerService.new("10.1/x").fetch
    assert_not out[:has_comments]
    assert_equal 0, out[:comment_count]
  end

  test "returns nil on other upstream errors" do
    stub_request(:get, /pubpeer\.com/).to_return(status: 500)
    assert_nil PubpeerService.new("10.1/x").fetch
  end
end
