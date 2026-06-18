require "net/http"
require "openssl"
require "json"
require "resolv"
require "ipaddr"

# Shared HTTP behaviour for every outbound API call.
#
# Responsibilities centralised here so individual services don't reinvent (or
# forget) them:
#   * connect/read timeouts on every request (a hung upstream must never pin a
#     Puma thread forever);
#   * a polite User-Agent;
#   * uniform error handling via #get_json (returns nil instead of raising, so
#     a transient network blip degrades a single criterion instead of 500-ing
#     the whole analysis);
#   * an SSRF guard (#safe_http_get) for URLs that come from user input.
module HttpClient
  MAX_REDIRECTS  = 3
  MAX_BODY_BYTES = 5 * 1024 * 1024 # bound memory on hostile/huge responses

  # Errors that simply mean "the upstream is unreachable / misbehaving".
  # Swallowed and turned into nil by #get_json / #safe_http_get.
  NETWORK_ERRORS = [
    Timeout::Error, Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::ECONNRESET,
    Errno::EHOSTUNREACH, Errno::ENETUNREACH, SocketError, OpenSSL::SSL::SSLError,
    Net::HTTPBadResponse, Net::OpenTimeout, Net::ReadTimeout, IOError, EOFError,
    URI::InvalidURIError, Resolv::ResolvError
  ].freeze

  # IP ranges that must never be reachable from a user-supplied URL (SSRF).
  # Notably includes 169.254.0.0/16, which covers the cloud metadata endpoint
  # 169.254.169.254.
  BLOCKED_IP_RANGES = [
    IPAddr.new("0.0.0.0/8"), IPAddr.new("10.0.0.0/8"), IPAddr.new("100.64.0.0/10"),
    IPAddr.new("127.0.0.0/8"), IPAddr.new("169.254.0.0/16"), IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.0.0.0/24"), IPAddr.new("192.168.0.0/16"), IPAddr.new("198.18.0.0/15"),
    IPAddr.new("::1/128"), IPAddr.new("fc00::/7"), IPAddr.new("fe80::/10")
  ].freeze

  def http_get(uri, headers: {}, open_timeout: Scicheck::Config::HTTP_OPEN_TIMEOUT,
               read_timeout: Scicheck::Config::HTTP_READ_TIMEOUT)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl      = uri.scheme == "https"
    http.cert_store   = ssl_store if http.use_ssl?
    http.open_timeout = open_timeout
    http.read_timeout = read_timeout

    http.start do |conn|
      request = Net::HTTP::Get.new(uri)
      default_headers.merge(headers).each { |k, v| request[k] = v }
      conn.request(request)
    end
  end

  # Fetch and parse JSON, returning nil on ANY failure (network, timeout,
  # non-2xx, malformed body). This is the method services should use.
  def get_json(uri, headers: {}, **opts)
    response = http_get(uri, headers: headers, **opts)
    return nil unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue *NETWORK_ERRORS, JSON::ParserError => e
    log_http_failure(uri, e)
    nil
  end

  # Like #http_get, but refuses to connect to private/loopback/link-local hosts
  # and to non-HTTP(S) schemes. Use for any URL derived from user input.
  # Re-checks every redirect hop. Returns the final body String, or nil.
  def safe_http_get_body(url, headers: {})
    uri = URI.parse(url.to_s)

    MAX_REDIRECTS.times do
      return nil unless public_http_uri?(uri)

      response = http_get(uri, headers: headers)
      case response
      when Net::HTTPRedirection
        location = response["location"]
        return nil if location.blank?
        uri = URI.join(uri, location) # resolve relative redirects against current uri
        next
      when Net::HTTPSuccess
        return read_capped_body(response)
      else
        return nil
      end
    end
    nil
  rescue *NETWORK_ERRORS => e
    log_http_failure(url, e)
    nil
  end

  # Public so it can be unit-tested directly.
  def public_http_uri?(uri)
    return false unless uri.is_a?(URI) && %w[http https].include?(uri.scheme)
    return false if uri.hostname.to_s.empty?

    addresses = Resolv.getaddresses(uri.hostname)
    return false if addresses.empty?

    addresses.all? { |ip| public_ip?(ip) }
  rescue Resolv::ResolvError, IPAddr::Error
    false
  end

  private

  def public_ip?(ip)
    addr = IPAddr.new(ip.to_s.split("%").first) # strip IPv6 zone id if present
    BLOCKED_IP_RANGES.none? { |range| range.include?(addr) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def read_capped_body(response)
    body = response.body.to_s
    body.byteslice(0, MAX_BODY_BYTES)
  end

  def default_headers
    {
      "User-Agent" => Scicheck::Config::USER_AGENT,
      "Accept"     => "application/json"
    }
  end

  def ssl_store
    store = OpenSSL::X509::Store.new
    store.set_default_paths
    # On macOS in development, CRL fetching often fails when revocation lists
    # are unreachable, aborting otherwise-valid TLS handshakes. We relax ONLY
    # the CRL flags there (VERIFY_PEER stays on). Never weaken TLS elsewhere.
    store.flags = 0 if defined?(Rails) && Rails.env.development?
    store
  end

  def log_http_failure(target, error)
    return unless defined?(Rails)
    Rails.logger.warn("[HttpClient] #{target} -> #{error.class}: #{error.message}")
  end
end
