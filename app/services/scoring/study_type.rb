module Scoring
  class StudyType
    # EBM evidence pyramid — strongest to weakest
    EBM_PYRAMID = {
      "meta-analysis"        => { level: 5, label: "Meta-analysis",              color: "green" },
      "systematic-review"    => { level: 5, label: "Systematic review",          color: "green" },
      "randomized-trial"     => { level: 4, label: "Randomized controlled trial", color: "green" },
      "controlled-trial"     => { level: 3, label: "Controlled trial",           color: "yellow" },
      "cohort-study"         => { level: 3, label: "Cohort study",               color: "yellow" },
      "case-control"         => { level: 2, label: "Case-control study",         color: "yellow" },
      "review"               => { level: 2, label: "Narrative review",           color: "yellow" },
      "article"              => { level: 2, label: "Original article",           color: "yellow" },
      "case-report"          => { level: 1, label: "Case report",               color: "orange" },
      "editorial"            => { level: 1, label: "Editorial",                 color: "orange" },
      "letter"               => { level: 1, label: "Letter",                    color: "orange" },
      "preprint"             => { level: 0, label: "Preprint (not peer-reviewed)", color: "red" }
    }.freeze

    def initialize(openalex_data, crossref_data)
      @openalex  = openalex_data
      @crossref  = crossref_data
    end

    def score
      type = detect_type
      info = EBM_PYRAMID[type] || { level: 1, label: "Unknown type", color: "gray" }

      {
        criterion:   "Study type",
        value:       info[:label],
        level:       info[:level],
        max_level:   5,
        color:       info[:color],
        explanation: explanation(info)
      }
    end

    private

    def detect_type
      # OpenAlex is the most reliable source for type
      raw = @openalex&.dig(:type)&.downcase
      return raw if EBM_PYRAMID.key?(raw)

      # Fallback to Crossref
      raw = @crossref&.dig(:type)&.downcase
      return "article" if raw == "journal-article"

      "article"
    end

    def explanation(info)
      case info[:level]
      when 5 then "Highest level of evidence. This study type synthesizes multiple research studies."
      when 4 then "High level of evidence. Random assignment limits bias."
      when 3 then "Moderate level of evidence. Useful but subject to selection bias."
      when 2 then "Limited level of evidence. Should be confirmed by other studies."
      when 1 then "Low level of evidence. Do not generalize the conclusions."
      when 0 then "Warning: this article has not yet been peer-reviewed."
      end
    end
  end
end
