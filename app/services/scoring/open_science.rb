module Scoring
  class OpenScience
    # Patterns indicating open data sharing
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
        criterion:   "Transparency (Open Science)",
        value:       matches.any? ? "Shared data detected" : "No sharing detected",
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
        [ 2, "green",  "Multiple data sharing indicators detected. Excellent transparency." ]
      elsif matches.length == 1
        [ 1, "yellow", "One transparency indicator detected. Good sign, but only partial sharing." ]
      else
        [ 0, "orange", "No links to data or source code detected in the abstract." ]
      end
    end
  end
end
