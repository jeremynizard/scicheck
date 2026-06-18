module Scoring
  class ReviewProcess
    def initialize(crossref_data, pubmed_data = nil)
      @crossref = crossref_data
      @pubmed   = pubmed_data
    end

    def score
      received, accepted, source_key = dates
      return unavailable if received.nil? || accepted.nil?

      days = (accepted - received).to_i
      return unavailable if days.negative? # inconsistent metadata, don't guess

      level, color = compute(days)

      {
        criterion:   I18n.t("scoring.review_process.name"),
        value:       I18n.t("scoring.review_process.value", days: days),
        level:       level,
        max_level:   3,
        color:       color,
        explanation: I18n.t("scoring.review_process.l#{level}", days: days),
        source_note: I18n.t("scoring.review_process.sources.#{source_key}"),
        days:        days
      }
    end

    private

    # Prefer Crossref assertions; fall back to PubMed history dates.
    def dates
      cr_received = @crossref&.dig(:received_date)
      cr_accepted = @crossref&.dig(:accepted_date)
      return [ cr_received, cr_accepted, :crossref ] if cr_received && cr_accepted

      pm_received = @pubmed&.dig(:received_date)
      pm_accepted = @pubmed&.dig(:accepted_date)
      return [ pm_received, pm_accepted, :pubmed ] if pm_received && pm_accepted

      [ nil, nil, nil ]
    end

    def compute(days)
      if days < 21
        [ 0, "red" ]
      elsif days < 60
        [ 1, "orange" ]
      elsif days <= 180
        [ 3, "green" ]
      else
        [ 2, "yellow" ]
      end
    end

    def unavailable
      {
        criterion:   I18n.t("scoring.review_process.name"),
        value:       I18n.t("scoring.review_process.unavailable_value"),
        level:       nil,
        max_level:   3,
        color:       "gray",
        explanation: I18n.t("scoring.review_process.unavailable")
      }
    end
  end
end
