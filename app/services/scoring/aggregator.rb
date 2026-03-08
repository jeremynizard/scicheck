module Scoring
  class Aggregator
    # Weight of each criterion on the global score
    # Weights must sum to 1.0
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

    def initialize(scores)
      @scores = scores
    end

    def aggregate
      global = compute_global_score
      # A PubPeer-flagged article cannot score above C (59/100)
      global = [ global, 59 ].min if pubpeer_flagged?

      {
        global_score: global,
        grade:        grade(global),
        color:        grade_color(global),
        summary:      summary(global),
        criteria:     @scores
      }
    end

    private

    def pubpeer_flagged?
      @scores.dig(:pubpeer, :level) == 0
    end

    def compute_global_score
      total_weight = 0.0
      weighted_sum = 0.0

      WEIGHTS.each do |key, weight|
        score = @scores[key]
        next if score.nil? || score[:level].nil?

        # Normalize score to 100
        normalized = (score[:level].to_f / score[:max_level]) * 100
        weighted_sum  += normalized * weight
        total_weight  += weight
      end

      return 0 if total_weight.zero?
      (weighted_sum / total_weight).round
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
      case score
      when 80..100
        "Good methodological quality. Key criteria are met."
      when 60..79
        "Acceptable article. Some points of concern identified."
      when 40..59
        "Average quality. Several important criteria are not met."
      when 20..39
        "Low quality article. Read with caution and cross-reference with other sources."
      else
        "Very low quality or from an unreliable source."
      end
    end
  end
end
