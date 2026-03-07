module Scoring
  class ReviewProcess
    def initialize(crossref_data)
      @data = crossref_data
    end

    def score
      received = @data&.dig(:received_date)
      accepted = @data&.dig(:accepted_date)

      if received.nil? || accepted.nil?
        return {
          criterion:   "Rigueur du processus",
          value:       "Donnees indisponibles",
          level:       nil,
          max_level:   3,
          color:       "gray",
          explanation: "Les dates de soumission et d'acceptation ne sont pas publiees par cet editeur."
        }
      end

      days = (accepted - received).to_i
      level, color, detail = compute(days)

      {
        criterion:   "Rigueur du processus",
        value:       "#{days} jours de review",
        level:       level,
        max_level:   3,
        color:       color,
        explanation: detail,
        days:        days
      }
    end

    private

    def compute(days)
      if days < 21
        [ 0, "red",    "Accepte en moins de 3 semaines. Signe possible d'une revue sans peer-review serieux." ]
      elsif days < 60
        [ 1, "orange", "Review rapide (#{days} jours). Possible mais a la limite basse pour un peer-review rigoureux." ]
      elsif days <= 180
        [ 3, "green",  "Duree de review normale (#{days} jours). Signe d'un processus de relecture serieux." ]
      else
        [ 2, "yellow", "Review longue (#{days} jours). Peut indiquer des revisions majeures ou un processus lent." ]
      end
    end
  end
end
