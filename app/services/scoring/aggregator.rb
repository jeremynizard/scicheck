module Scoring
  class Aggregator
    # Weight of each criterion on the global score. Must sum to 1.0.
    WEIGHTS = {
      study_type:            0.25,
      review_pedigree:       0.20,
      review_process:        0.15,
      open_science:          0.10,
      pubpeer:               0.10,
      citation_profile:      0.08,
      retracted_references:  0.07,
      author_track_record:   0.05
    }.freeze

    # Caps applied after the weighted average (a great score on other axes
    # cannot paper over a serious post-publication concern).
    RETRACTED_CAP        = 12  # the analyzed article is itself retracted
    PUBPEER_MAJOR_CAP    = 59  # >= 3 PubPeer comments
    PUBPEER_MINOR_CAP    = 74  # 1-2 PubPeer comments

    def initialize(scores, retracted: false)
      @scores    = scores
      @retracted = retracted
    end

    def aggregate
      global  = compute_global_score
      notices = []

      if @retracted
        global = [ global, RETRACTED_CAP ].min
        notices << :retracted
      elsif (cap = pubpeer_cap) && global > cap
        global = cap
        notices << :pubpeer
      end

      {
        global_score: global,
        grade:        grade(global),
        color:        grade_color(global),
        summary:      summary(global),
        criteria:     @scores,
        coverage:     coverage,
        notices:      notices,
        retracted:    @retracted
      }
    end

    private

    # Graded cap based on how many PubPeer comments exist.
    def pubpeer_cap
      pp = @scores[:pubpeer]
      return nil unless pp && pp[:level] == 0

      count = pp[:comment_count].to_i
      return nil if count.zero? # level 0 with no counted comments → don't cap

      count >= 3 ? PUBPEER_MAJOR_CAP : PUBPEER_MINOR_CAP
    end

    def compute_global_score
      total_weight = 0.0
      weighted_sum = 0.0

      WEIGHTS.each do |key, weight|
        score = @scores[key]
        next if score.nil? || score[:level].nil?

        normalized   = (score[:level].to_f / score[:max_level]) * 100
        weighted_sum += normalized * weight
        total_weight += weight
      end

      return 0 if total_weight.zero?
      (weighted_sum / total_weight).round
    end

    # Transparency about renormalization: how many criteria actually counted,
    # so the UI can disclose that the score rests on a subset.
    def coverage
      counted     = []
      unavailable = []

      WEIGHTS.each_key do |key|
        score = @scores[key]
        if score.nil? || score[:level].nil?
          unavailable << (score&.dig(:criterion) || key.to_s.tr("_", " ").capitalize)
        else
          counted << key
        end
      end

      {
        counted:     counted.size,
        total:       WEIGHTS.size,
        weight_used: WEIGHTS.values_at(*counted).sum.round(2),
        unavailable: unavailable
      }
    end

    def grade(score)
      case score
      when 80..100 then "A"
      when 60..79  then "B"
      when 40..59  then "C"
      when 20..39  then "D"
      else              "E"
      end
    end

    def grade_color(score)
      case score
      when 80..100 then "green"
      when 60..79  then "yellow-green"
      when 40..59  then "yellow"
      when 20..39  then "orange"
      else              "red"
      end
    end

    def summary(score)
      key = case score
      when 80..100 then :a
      when 60..79  then :b
      when 40..59  then :c
      when 20..39  then :d
      else              :e
      end
      I18n.t("scoring.aggregator.summary.#{key}")
    end
  end
end
