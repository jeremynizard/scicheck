module Scoring
  class ReviewPedigree
    def initialize(openalex_data)
      @data = openalex_data
    end

    def score
      is_in_doaj = @data&.dig(:is_in_doaj)
      is_core    = @data&.dig(:is_core)
      indexed_in = @data&.dig(:indexed_in) || []
      in_pubmed  = indexed_in.include?("pubmed")

      level, color, detail = compute(is_in_doaj, is_core, in_pubmed)

      {
        criterion:   "Journal pedigree",
        value:       @data&.dig(:journal_name) || "Unknown",
        level:       level,
        max_level:   3,
        color:       color,
        explanation: detail,
        badges:      build_badges(is_in_doaj, is_core, in_pubmed)
      }
    end

    private

    def compute(is_in_doaj, is_core, in_pubmed)
      if is_core && in_pubmed
        [ 3, "green", "Journal indexed in major reference databases (PubMed, Scopus). High credibility." ]
      elsif is_core || in_pubmed
        [ 2, "yellow", "Journal partially indexed. Reasonable credibility but worth verifying." ]
      elsif is_in_doaj
        [ 1, "orange", "Journal listed in DOAJ but absent from major databases. Limited credibility." ]
      else
        [ 0, "red", "Journal not indexed in reputable databases. Possible predatory journal." ]
      end
    end

    def build_badges(is_in_doaj, is_core, in_pubmed)
      [
        { label: "PubMed",  present: in_pubmed },
        { label: "Core",    present: is_core },
        { label: "DOAJ",    present: is_in_doaj }
      ]
    end
  end
end
