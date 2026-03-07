require "net/http"
require "openssl"

module HttpClient
  def http_get(uri, headers: {})
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, cert_store: ssl_store) do |http|
      request = Net::HTTP::Get.new(uri)
      headers.each { |k, v| request[k] = v }
      http.request(request)
    end
  end

  private

  def ssl_store
    store = OpenSSL::X509::Store.new
    store.set_default_paths
    # flags = 0 desactive la verification CRL qui echoue sur macOS quand les
    # listes de revocation sont inaccessibles, sans desactiver VERIFY_PEER.
    store.flags = 0
    store
  end
end
