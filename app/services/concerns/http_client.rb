require "net/http"
require "openssl"

module HttpClient
  # TODO: En production, remplacer VERIFY_NONE par VERIFY_PEER avec un CA bundle valide.
  # En dev sur macOS, OpenSSL echoue a verifier les CRL (Certificate Revocation Lists)
  # des APIs tierces (Crossref, OpenAlex), ce qui bloque toutes les connexions HTTPS.
  SSL_PARAMS = { use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE }.freeze

  def http_get(uri, headers: {})
    Net::HTTP.start(uri.hostname, uri.port, **SSL_PARAMS) do |http|
      request = Net::HTTP::Get.new(uri)
      headers.each { |k, v| request[k] = v }
      http.request(request)
    end
  end
end
