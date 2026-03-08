module Scoring
  class RetractedReferences
    def initialize(retraction_data)
      @data = retraction_data
    end

    def score
      return unavailable if @data.nil? || @data[:checked].zero?

      count = @data[:retracted_count]
      level, color, detail = compute(count)

      result = {
        criterion:   "Retracted references",
        value:       count.zero? ? "No retracted references" : "#{count} retracted reference(s)",
        level:       level,
        max_level:   2,
        color:       color,
        explanation: detail
      }

      if @data[:retracted_dois].any?
        result[:detected] = @data[:retracted_dois].map { |doi| "doi.org/#{doi}" }
      end

      result
    end

    private

    def compute(count)
      case count
      when 0
        [ 2, "green", "None of the #{@data[:checked]} cited references have been retracted." ]
      when 1
        [ 1, "orange", "One cited reference has been retracted. Check if the article's conclusions depend on this source." ]
      else
        [ 0, "red", "#{count} cited references have been retracted. The article's conclusions may be compromised." ]
      end
    end

    def unavailable
      {
        criterion:   "Retracted references",
        value:       "Not verifiable",
        level:       nil,
        max_level:   2,
        color:       "gray",
        explanation: "No references available to check for retractions."
      }
    end
  end
end
