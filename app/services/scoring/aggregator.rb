module Scoring
  class Aggregator
    # Ponderation de chaque critere sur le score global
    # La somme des poids doit etre egale a 1.0
    WEIGHTS = {
      study_type:      0.30,
      review_pedigree: 0.25,
      review_process:  0.20,
      open_science:    0.15,
      pubpeer:         0.10
    }.freeze

    def initialize(scores)
      @scores = scores
    end

    def aggregate
      global = compute_global_score
      # Un article signale sur PubPeer ne peut pas depasser C (59/100)
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

        # Normalise le score sur 100
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
        "Article de bonne qualite methodologique. Les criteres principaux sont satisfaits."
      when 60..79
        "Article acceptable. Quelques points de vigilance identifies."
      when 40..59
        "Article de qualite moyenne. Plusieurs criteres importants ne sont pas satisfaits."
      when 20..39
        "Article de faible qualite. A lire avec prudence et a croiser avec d'autres sources."
      else
        "Article de tres faible qualite ou provenant d'une source non fiable."
      end
    end
  end
end
