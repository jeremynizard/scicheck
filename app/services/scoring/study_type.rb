module Scoring
  class StudyType
    # Pyramide des preuves EBM — du plus fort au plus faible
    EBM_PYRAMID = {
      "meta-analysis"        => { level: 5, label: "Meta-analyse",         color: "green" },
      "systematic-review"    => { level: 5, label: "Revue systematique",   color: "green" },
      "randomized-trial"     => { level: 4, label: "Essai randomise (RCT)", color: "green" },
      "controlled-trial"     => { level: 3, label: "Essai controle",       color: "yellow" },
      "cohort-study"         => { level: 3, label: "Etude de cohorte",     color: "yellow" },
      "case-control"         => { level: 2, label: "Etude cas-temoin",     color: "yellow" },
      "review"               => { level: 2, label: "Revue narrative",      color: "yellow" },
      "article"              => { level: 2, label: "Article original",     color: "yellow" },
      "case-report"          => { level: 1, label: "Rapport de cas",       color: "orange" },
      "editorial"            => { level: 1, label: "Editorial",            color: "orange" },
      "letter"               => { level: 1, label: "Lettre",              color: "orange" },
      "preprint"             => { level: 0, label: "Preprint (non relu)",  color: "red" }
    }.freeze

    def initialize(openalex_data, crossref_data)
      @openalex  = openalex_data
      @crossref  = crossref_data
    end

    def score
      type = detect_type
      info = EBM_PYRAMID[type] || { level: 1, label: "Type inconnu", color: "gray" }

      {
        criterion:   "Type d'etude",
        value:       info[:label],
        level:       info[:level],
        max_level:   5,
        color:       info[:color],
        explanation: explanation(info)
      }
    end

    private

    def detect_type
      # OpenAlex est la source la plus fiable pour le type
      raw = @openalex&.dig(:type)&.downcase
      return raw if EBM_PYRAMID.key?(raw)

      # Fallback sur Crossref
      raw = @crossref&.dig(:type)&.downcase
      return "article" if raw == "journal-article"

      "article"
    end

    def explanation(info)
      case info[:level]
      when 5 then "Niveau de preuve maximal. Ce type d'etude synthetise plusieurs recherches."
      when 4 then "Niveau de preuve eleve. L'assignation aleatoire limite les biais."
      when 3 then "Niveau de preuve moyen. Utile mais sujet a des biais de selection."
      when 2 then "Niveau de preuve limite. A confirmer avec d'autres etudes."
      when 1 then "Niveau de preuve faible. Ne pas generaliser les conclusions."
      when 0 then "Attention : cet article n'a pas encore ete relu par des pairs."
      end
    end
  end
end
