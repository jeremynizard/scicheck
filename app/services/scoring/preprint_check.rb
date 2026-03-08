module Scoring
  class PreprintCheck
    # Known DOI prefixes for preprint servers
    PREPRINT_DOI_PREFIXES = %w[10.1101 10.21203 10.31234 10.31730 10.22541].freeze
    PREPRINT_SOURCES      = %w[biorxiv medrxiv ssrn osf preprint].freeze

    def initialize(openalex_data, crossref_data)
      @openalex = openalex_data
      @crossref = crossref_data
    end

    def score
      is_preprint = detect_preprint

      if is_preprint
        {
          criterion:   "Article status",
          value:       "Preprint (not peer-reviewed)",
          level:       0,
          max_level:   1,
          color:       "red",
          explanation: "This article has not yet undergone peer review. " \
                       "Its conclusions are preliminary and unvalidated."
        }
      else
        {
          criterion:   "Article status",
          value:       "Published in a journal",
          level:       1,
          max_level:   1,
          color:       "green",
          explanation: "This article has been published in an academic journal with a peer-review process."
        }
      end
    end

    private

    def detect_preprint
      # 1. OpenAlex directly flags preprints
      return true if @openalex&.dig(:type) == "preprint"

      # 2. Check DOI prefix (10.1101 = bioRxiv/medRxiv)
      doi = @crossref&.dig(:doi) || ""
      return true if PREPRINT_DOI_PREFIXES.any? { |prefix| doi.start_with?(prefix) }

      # 3. Check source name
      source = @openalex&.dig(:journal_name)&.downcase || ""
      return true if PREPRINT_SOURCES.any? { |s| source.include?(s) }

      false
    end
  end
end
