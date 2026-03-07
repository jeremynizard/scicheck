module Scoring
  class OpenScience
    # Patterns signalant un partage de donnees ouvertes
    DATA_PATTERNS = [
      /github\.com/i,
      /gitlab\.com/i,
      /zenodo\.org/i,
      /osf\.io/i,
      /figshare\.com/i,
      /data\s+availab/i,
      /data\s+sharing/i,
      /open\s+data/i,
      /ClinicalTrials\.gov/i,
      /PROSPERO/i,
      /dryad/i
    ].freeze

    def initialize(crossref_data)
      @data = crossref_data
    end

    def score
      abstract = @data&.dig(:abstract) || ""
      matches  = find_matches(abstract)

      level, color, detail = compute(matches)

      {
        criterion:   "Transparence (Open Science)",
        value:       matches.any? ? "Donnees partagees detectees" : "Aucun partage detecte",
        level:       level,
        max_level:   2,
        color:       color,
        explanation: detail,
        detected:    matches
      }
    end

    private

    def find_matches(text)
      DATA_PATTERNS.filter_map do |pattern|
        match = text.match(pattern)
        match&.to_s
      end
    end

    def compute(matches)
      if matches.length >= 2
        [2, "green",  "Plusieurs indicateurs de partage de donnees detectes. Excellente transparence."]
      elsif matches.length == 1
        [1, "yellow", "Un indicateur de transparence detecte. Bon signal, mais partage partiel."]
      else
        [0, "orange", "Aucun lien vers des donnees ou code source detecte dans l'abstract."]
      end
    end
  end
end
