module Scoring
  class AuthorTrackRecord
    def initialize(author_profiles)
      @profiles = author_profiles || []
    end

    def score
      return unavailable if @profiles.empty?

      max_h = @profiles.filter_map { |p| p[:h_index] }.max || 0
      all_affiliated = @profiles.all? { |p| p[:institutions]&.any? }
      level, color, detail = compute(max_h, all_affiliated)

      {
        criterion:   "Author track record",
        value:       "Max h-index: #{max_h}",
        level:       level,
        max_level:   3,
        color:       color,
        explanation: detail
      }
    end

    private

    def compute(max_h, all_affiliated)
      if max_h >= 20 && all_affiliated
        [ 3, "green", "At least one author is an established researcher (h-index >= 20) with institutional affiliation." ]
      elsif max_h >= 10 || all_affiliated
        [ 2, "yellow", "Authors with publication experience. #{all_affiliated ? 'All affiliated with institutions.' : "Max h-index of #{max_h}."}" ]
      elsif max_h >= 3
        [ 1, "orange", "Authors with few publications. Consider in the context of the field." ]
      else
        [ 0, "red", "Authors with no significant publication history or insufficient data." ]
      end
    end

    def unavailable
      {
        criterion:   "Author track record",
        value:       "Data unavailable",
        level:       nil,
        max_level:   3,
        color:       "gray",
        explanation: "Unable to retrieve author profiles from OpenAlex."
      }
    end
  end
end
