# Runs the full analysis pipeline for a single DOI and returns a plain hash
# ({ doi:, result:, meta: }) suitable for caching and rendering. Returns nil if
# the DOI cannot be found in either Crossref or OpenAlex.
#
# Kept free of any web/caching concerns so it can be unit-tested in isolation
# and reused (e.g. from a background job later).
class AnalysisRunner
  def initialize(doi)
    @doi = doi.to_s.strip
  end

  def call
    return nil if @doi.empty?

    crossref, openalex, pubpeer = fetch_primary
    return nil if crossref.nil? && openalex.nil?

    pubmed, retraction, profiles = fetch_secondary(crossref, openalex)

    scores = build_scores(crossref, openalex, pubpeer, pubmed, retraction, profiles)
    result = Scoring::Aggregator.new(scores, retracted: openalex&.dig(:is_retracted) == true).aggregate
    meta   = build_meta(crossref, openalex, profiles)

    { doi: @doi, result: result, meta: meta }
  end

  private

  def fetch_primary
    crossref = openalex = pubpeer = nil
    [
      fetch_in_thread { crossref = CrossrefService.new(@doi).fetch },
      fetch_in_thread { openalex = OpenalexService.new(@doi).fetch },
      fetch_in_thread { pubpeer  = PubpeerService.new(@doi).fetch }
    ].each(&:join)
    [ crossref, openalex, pubpeer ]
  end

  # Second wave: PubMed (needs the PMID from OpenAlex), retracted-reference
  # checks (need Crossref references) and author profiles (need OpenAlex
  # authorships) — all independent, so they run together.
  def fetch_secondary(crossref, openalex)
    pubmed = retraction = profiles = nil
    [
      fetch_in_thread { pubmed     = PubmedService.new(openalex&.dig(:pmid)).fetch },
      fetch_in_thread { retraction = OpenalexRetractionService.new(crossref&.dig(:references)).fetch },
      fetch_in_thread { profiles   = OpenalexAuthorService.new(openalex&.dig(:authorships)).fetch }
    ].each(&:join)
    [ pubmed, retraction, profiles ]
  end

  # Wrap every thread body so a bug in one service cannot crash the request
  # (services already swallow network errors, this guards against the rest).
  def fetch_in_thread(&block)
    Thread.new do
      block.call
    rescue StandardError => e
      Rails.logger.error("[AnalysisRunner] #{e.class}: #{e.message}") if defined?(Rails)
      nil
    end
  end

  def build_scores(crossref, openalex, pubpeer, pubmed, retraction, profiles)
    {
      study_type:           Scoring::StudyType.new(openalex, crossref, pubmed).score,
      review_pedigree:      Scoring::ReviewPedigree.new(openalex).score,
      review_process:       Scoring::ReviewProcess.new(crossref, pubmed).score,
      open_science:         Scoring::OpenScience.new(crossref, pubmed, openalex).score,
      pubpeer:              Scoring::PubpeerCheck.new(pubpeer).score,
      citation_profile:     Scoring::CitationProfile.new(openalex).score,
      retracted_references: Scoring::RetractedReferences.new(retraction).score,
      author_track_record:  Scoring::AuthorTrackRecord.new(profiles).score
    }
  end

  def build_meta(crossref, openalex, profiles)
    {
      doi:       @doi,
      title:     crossref&.dig(:title) || openalex&.dig(:journal_name),
      abstract:  crossref&.dig(:abstract).presence || openalex&.dig(:abstract),
      authors:   build_authors(crossref, openalex, profiles),
      journal:   crossref&.dig(:journal) || openalex&.dig(:journal_name),
      published: crossref&.dig(:published_date) || openalex&.dig(:publication_date),
      url:       crossref&.dig(:url) || openalex&.dig(:oa_url),
      topics:    openalex&.dig(:topics) || [],
      oa_status: openalex&.dig(:oa_status),
      retracted: openalex&.dig(:is_retracted) == true
    }
  end

  # Match author profiles to authorships by OpenAlex id (robust), not by name
  # (which fails on initials/diacritics/ordering). Prefer OpenAlex authorships
  # as the source of truth; fall back to Crossref authors.
  def build_authors(crossref, openalex, profiles)
    profile_by_id = Array(profiles).index_by { |p| p[:openalex_id] }
    authorships   = openalex&.dig(:authorships)

    if authorships.present?
      authorships.map do |a|
        profile = profile_by_id[a[:openalex_id]]
        {
          name:         a[:name],
          h_index:      profile&.dig(:h_index),
          institutions: profile&.dig(:institutions).presence || a[:institutions]
        }
      end
    else
      Array(crossref&.dig(:authors)).map do |a|
        { name: a[:name], h_index: nil, institutions: Array(a[:affiliation]).compact }
      end
    end
  end
end
