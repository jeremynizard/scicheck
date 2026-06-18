require "test_helper"

class LlmClientTest < ActiveSupport::TestCase
  def chat_body(content)
    { choices: [ { message: { content: content } } ] }.to_json
  end

  test "returns nil when no API key is configured — and makes no HTTP call" do
    assert_nil LlmClient.new(api_key: nil).chat([ { role: "user", content: "hi" } ])
  end

  test "returns the assistant content when configured" do
    stub_request(:post, %r{/chat/completions}).to_return(status: 200, body: chat_body("hello"))
    assert_equal "hello", LlmClient.new(api_key: "test-key").chat([ { role: "user", content: "hi" } ])
  end

  test "returns nil on an upstream error" do
    stub_request(:post, %r{/chat/completions}).to_return(status: 500)
    assert_nil LlmClient.new(api_key: "test-key").chat([ { role: "user", content: "hi" } ])
  end

  test "sends a Bearer Authorization header with the key" do
    stub = stub_request(:post, %r{/chat/completions})
      .with(headers: { "Authorization" => "Bearer test-key" })
      .to_return(status: 200, body: chat_body("ok"))
    LlmClient.new(api_key: "test-key").chat([ { role: "user", content: "hi" } ])
    assert_requested(stub)
  end
end
