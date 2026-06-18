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

      level, color = compute(is_in_doaj, is_core, in_pubmed)

      {
        criterion:   I18n.t("scoring.review_pedigree.name"),
        value:       @data&.dig(:journal_name) || I18n.t("scoring.review_pedigree.unknown"),
        level:       level,
        max_level:   3,
        color:       color,
        explanation: I18n.t("scoring.review_pedigree.l#{level}"),
        badges:      build_badges(is_in_doaj, is_core, in_pubmed)
      }
    end

    private

    def compute(is_in_doaj, is_core, in_pubmed)
      if is_core && in_pubmed
        [ 3, "green" ]
      elsif is_core || in_pubmed
        [ 2, "yellow" ]
      elsif is_in_doaj
        [ 1, "orange" ]
      else
        [ 0, "red" ]
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
