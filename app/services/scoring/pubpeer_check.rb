module Scoring
  # Post-publication scrutiny on PubPeer. Any comment is a flag *for manual
  # review*, not proof of fault (the public API exposes only a count). The
  # aggregator applies a graded, not all-or-nothing, cap.
  class PubpeerCheck
    def initialize(pubpeer_data)
      @data = pubpeer_data
    end

    def score
      return unavailable if @data.nil?

      if @data[:has_comments]
        count = @data[:comment_count].to_i
        {
          criterion:     I18n.t("scoring.pubpeer.name"),
          value:         I18n.t("scoring.pubpeer.value_comments", count: count),
          level:         0,
          max_level:     1,
          color:         count >= 3 ? "red" : "orange",
          comment_count: count,
          explanation:   I18n.t("scoring.pubpeer.flagged"),
          pubpeer_url:   @data[:url]
        }
      else
        {
          criterion:     I18n.t("scoring.pubpeer.name"),
          value:         I18n.t("scoring.pubpeer.value_none"),
          level:         1,
          max_level:     1,
          color:         "green",
          comment_count: 0,
          explanation:   I18n.t("scoring.pubpeer.clean"),
          pubpeer_url:   nil
        }
      end
    end

    private

    def unavailable
      {
        criterion:   I18n.t("scoring.pubpeer.name"),
        value:       I18n.t("scoring.pubpeer.value_unavailable"),
        level:       nil,
        max_level:   1,
        color:       "gray",
        explanation: I18n.t("scoring.pubpeer.unavailable")
      }
    end
  end
end
