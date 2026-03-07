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
        criterion:   "Pedigree de la revue",
        value:       @data&.dig(:journal_name) || "Inconnue",
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
        [ 3, "green", "Revue indexee dans les grandes bases de references (PubMed, Scopus). Haut niveau de credibilite." ]
      elsif is_core || in_pubmed
        [ 2, "yellow", "Revue partiellement indexee. Credibilite correcte mais a verifier." ]
      elsif is_in_doaj
        [ 1, "orange", "Revue presente dans le DOAJ mais absente des grandes bases. Credibilite limitee." ]
      else
        [ 0, "red", "Revue non indexee dans les bases serieuses. Risque de revue predatrice." ]
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
