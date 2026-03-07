module Scoring
  class PreprintCheck
    # Prefixes DOI connus des serveurs de preprints
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
          criterion:   "Statut de l'article",
          value:       "Preprint (non relu par des pairs)",
          level:       0,
          max_level:   1,
          color:       "red",
          explanation: "Cet article n'a pas encore ete soumis a un processus de peer-review. " \
                       "Ses conclusions sont preliminaires et non validees."
        }
      else
        {
          criterion:   "Statut de l'article",
          value:       "Article publie dans une revue",
          level:       1,
          max_level:   1,
          color:       "green",
          explanation: "Cet article a ete publie dans une revue academique avec processus de peer-review."
        }
      end
    end

    private

    def detect_preprint
      # 1. OpenAlex marque directement les preprints
      return true if @openalex&.dig(:type) == "preprint"

      # 2. Verifier le prefixe DOI (10.1101 = bioRxiv/medRxiv)
      doi = @crossref&.dig(:doi) || ""
      return true if PREPRINT_DOI_PREFIXES.any? { |prefix| doi.start_with?(prefix) }

      # 3. Verifier le nom de la source
      source = @openalex&.dig(:journal_name)&.downcase || ""
      return true if PREPRINT_SOURCES.any? { |s| source.include?(s) }

      false
    end
  end
end
