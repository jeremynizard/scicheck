module Scoring
  class AuthorTrackRecord
    def initialize(author_profiles)
      @profiles = author_profiles || []
    end

    def score
      return unavailable if @profiles.empty?

      max_h = @profiles.filter_map { |p| p[:h_index] }.max || 0
      all_affiliated = @profiles.all? { |p| p[:institutions]&.any? }
      level, color = compute(max_h, all_affiliated)

      {
        criterion:   I18n.t("scoring.author_track_record.name"),
        value:       I18n.t("scoring.author_track_record.value", max_h: max_h),
        level:       level,
        max_level:   3,
        color:       color,
        explanation: explanation(level, max_h, all_affiliated)
      }
    end

    private

    def compute(max_h, all_affiliated)
      if max_h >= 20 && all_affiliated
        [ 3, "green" ]
      elsif max_h >= 10 || all_affiliated
        [ 2, "yellow" ]
      elsif max_h >= 3
        [ 1, "orange" ]
      else
        [ 0, "red" ]
      end
    end

    def explanation(level, max_h, all_affiliated)
      case level
      when 3 then I18n.t("scoring.author_track_record.l3")
      when 2 then all_affiliated ? I18n.t("scoring.author_track_record.l2_affiliated") : I18n.t("scoring.author_track_record.l2_h_index", max_h: max_h)
      when 1 then I18n.t("scoring.author_track_record.l1")
      else        I18n.t("scoring.author_track_record.l0")
      end
    end

    def unavailable
      {
        criterion:   I18n.t("scoring.author_track_record.name"),
        value:       I18n.t("scoring.author_track_record.value_unavailable"),
        level:       nil,
        max_level:   3,
        color:       "gray",
        explanation: I18n.t("scoring.author_track_record.unavailable")
      }
    end
  end
end
