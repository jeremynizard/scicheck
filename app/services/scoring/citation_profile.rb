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

      level, color = compute(percentile)

      {
        criterion:   I18n.t("scoring.citation_profile.name"),
        value:       I18n.t("scoring.citation_profile.value", percentile: percentile),
        level:       level,
        max_level:   3,
        color:       color,
        explanation: explanation(level, percentile)
      }
    end

    private

    def compute(percentile)
      case percentile
      when 75..100 then [ 3, "green" ]
      when 50..74  then [ 2, "yellow" ]
      when 25..49  then [ 1, "orange" ]
      else              [ 0, "red" ]
      end
    end

    def explanation(level, percentile)
      case level
      when 3 then I18n.t("scoring.citation_profile.l3", top: 100 - percentile)
      when 2 then I18n.t("scoring.citation_profile.l2", percentile: percentile)
      when 1 then I18n.t("scoring.citation_profile.l1")
      else        I18n.t("scoring.citation_profile.l0")
      end
    end

    def too_recent
      {
        criterion:   I18n.t("scoring.citation_profile.name"),
        value:       I18n.t("scoring.citation_profile.value_too_recent"),
        level:       nil,
        max_level:   3,
        color:       "gray",
        explanation: I18n.t("scoring.citation_profile.too_recent")
      }
    end

    def unavailable
      {
        criterion:   I18n.t("scoring.citation_profile.name"),
        value:       I18n.t("scoring.citation_profile.value_unavailable"),
        level:       nil,
        max_level:   3,
        color:       "gray",
        explanation: I18n.t("scoring.citation_profile.unavailable")
      }
    end
  end
end
