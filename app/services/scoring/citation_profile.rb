module Scoring
  class CitationProfile
    def initialize(openalex_data)
      @data = openalex_data
    end

    def score
      return unavailable if @data.nil?

      percentile = @data[:cited_by_percentile_year]
      return too_recent if percentile.nil?

      pub_year = @data[:publication_year]
      return too_recent if pub_year && pub_year >= Date.today.year

      level, color, detail = compute(percentile)

      {
        criterion:   "Citation profile",
        value:       "Percentile #{percentile}/100",
        level:       level,
        max_level:   3,
        color:       color,
        explanation: detail
      }
    end

    private

    def compute(percentile)
      case percentile
      when 75..100
        [ 3, "green", "Highly cited article for its field and publication year (top #{100 - percentile}%)." ]
      when 50..74
        [ 2, "yellow", "Article in the upper half of citations for its field (percentile #{percentile})." ]
      when 25..49
        [ 1, "orange", "Article with below-average citations for its field and publication year." ]
      else
        [ 0, "red", "Very low citation count compared to other publications in the same field." ]
      end
    end

    def too_recent
      {
        criterion:   "Citation profile",
        value:       "Too recent",
        level:       nil,
        max_level:   3,
        color:       "gray",
        explanation: "Article published too recently to evaluate its citation impact."
      }
    end

    def unavailable
      {
        criterion:   "Citation profile",
        value:       "Data unavailable",
        level:       nil,
        max_level:   3,
        color:       "gray",
        explanation: "Unable to retrieve citation data for this article."
      }
    end
  end
end
