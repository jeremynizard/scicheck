module Scoring
  class RetractedReferences
    def initialize(retraction_data)
      @data = retraction_data
    end

    def score
      return unavailable if @data.nil? || @data[:checked].zero?

      count = @data[:retracted_count]
      level, color = compute(count)

      result = {
        criterion:   I18n.t("scoring.retracted_references.name"),
        value:       value_for(count),
        level:       level,
        max_level:   2,
        color:       color,
        explanation: explanation(count)
      }

      if @data[:retracted_dois].any?
        result[:detected] = @data[:retracted_dois].map { |doi| "doi.org/#{doi}" }
      end

      result
    end

    private

    def compute(count)
      case count
      when 0 then [ 2, "green" ]
      when 1 then [ 1, "orange" ]
      else        [ 0, "red" ]
      end
    end

    def value_for(count)
      return I18n.t("scoring.retracted_references.value_none") if count.zero?
      I18n.t("scoring.retracted_references.value_some", count: count)
    end

    def explanation(count)
      case count
      when 0 then I18n.t("scoring.retracted_references.l2", checked: @data[:checked])
      when 1 then I18n.t("scoring.retracted_references.l1")
      else        I18n.t("scoring.retracted_references.l0", count: count)
      end
    end

    def unavailable
      {
        criterion:   I18n.t("scoring.retracted_references.name"),
        value:       I18n.t("scoring.retracted_references.value_unverifiable"),
        level:       nil,
        max_level:   2,
        color:       "gray",
        explanation: I18n.t("scoring.retracted_references.unavailable")
      }
    end
  end
end
