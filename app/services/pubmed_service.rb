require "rexml/document"

# Fetches a PubMed record via NCBI E-utilities (efetch, XML) given a PMID.
#
# This is the source that actually carries *study design* — OpenAlex/Crossref
# only expose the editorial document type ("article", "review"), whereas PubMed
# tags the MeSH Publication Types ("Randomized Controlled Trial",
# "Meta-Analysis", "Systematic Review", "Case Reports", ...). It also exposes
# registered data banks (ClinicalTrials.gov, GEO, ...) and conflict-of-interest
# statements, which feed the transparency criterion.
class PubmedService
  include HttpClient

  BASE_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"

  def initialize(pmid)
    @pmid = pmid.to_s.strip
  end

  def fetch
    return nil if @pmid.empty? || @pmid !~ /\A\d+\z/

    response = http_get(efetch_uri, headers: { "Accept" => "application/xml" })
    return nil unless response.is_a?(Net::HTTPSuccess)

    doc = REXML::Document.new(response.body)
    return nil if doc.root.nil?

    {
      pmid:              @pmid,
      publication_types: texts(doc, "//PublicationType"),
      data_banks:        texts(doc, "//DataBank/DataBankName").uniq,
      # All MeSH subject headings (capped for safety). Used both for display and
      # to refine the observational study design — cohort/case-control/etc. are
      # MeSH headings, not publication types.
      mesh_terms:        texts(doc, "//MeshHeading/DescriptorName").first(40),
      has_coi_statement: coi_present?(doc),
      received_date:     history_date(doc, "received"),
      accepted_date:     history_date(doc, "accepted")
    }
  rescue *NETWORK_ERRORS, REXML::ParseException => e
    log_http_failure(efetch_uri, e)
    nil
  end

  private

  def efetch_uri
    params = {
      db: "pubmed", id: @pmid, retmode: "xml",
      tool: "scicheck", email: Scicheck::Config::CONTACT_EMAIL
    }
    params[:api_key] = Scicheck::Config::NCBI_API_KEY if Scicheck::Config::NCBI_API_KEY
    URI("#{BASE_URL}?#{URI.encode_www_form(params)}")
  end

  def texts(doc, xpath)
    REXML::XPath.match(doc, xpath).filter_map { |el| el.text&.strip }.reject(&:empty?)
  end

  def coi_present?(doc)
    !REXML::XPath.first(doc, "//CoiStatement").nil?
  end

  # PubMed history dates look like:
  #   <PubMedPubDate PubStatus="received"><Year>2024</Year><Month>1</Month><Day>5</Day></PubMedPubDate>
  def history_date(doc, status)
    node = REXML::XPath.first(doc, "//PubMedPubDate[@PubStatus='#{status}']")
    return nil unless node

    year  = node.elements["Year"]&.text
    month = node.elements["Month"]&.text || "1"
    day   = node.elements["Day"]&.text || "1"
    return nil if year.nil?

    Date.new(year.to_i, month.to_i, day.to_i)
  rescue ArgumentError, TypeError
    nil
  end
end
