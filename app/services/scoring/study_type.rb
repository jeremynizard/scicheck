module Scoring
  # Ranks an article on the evidence-based-medicine pyramid.
  #
  # The key insight: OpenAlex/Crossref only know the *editorial* document type
  # ("article", "review"), which cannot tell a systematic review from an opinion
  # piece or an RCT from a case report. PubMed's MeSH Publication Types do carry
  # the study *design*, so when a PMID is available we rank from those and only
  # fall back to the coarse OpenAlex/Crossref type otherwise.
  #
  # Detection carries i18n KEYS (:type_key, :source_key); #score translates them
  # under the current locale.
  class StudyType
    PREPRINT_DOI_PREFIXES = %w[10.1101 10.21203 10.31234 10.31730 10.22541 10.48550].freeze

    # (matcher, level, type_key, color) — strongest evidence first. The first
    # publication type that matches (scanning top-down) wins.
    RANKED_TYPES = [
      [ /\Ameta-analysis\z/i,               5, :meta_analysis,     "green" ],
      [ /\Asystematic review\z/i,           5, :systematic_review, "green" ],
      [ /\A(practice )?guideline\z/i,       4, :guideline,         "green" ],
      [ /\Arandomized controlled trial\z/i, 4, :rct,               "green" ],
      [ /\Acontrolled clinical trial\z/i,   3, :controlled_trial,  "yellow" ],
      [ /\Aclinical trial(,.*)?\z/i,        3, :clinical_trial,    "yellow" ],
      [ /\Aobservational study\z/i,         3, :observational,     "yellow" ],
      [ /\Acase reports?\z/i,               1, :case_report,       "orange" ],
      [ /\Areview\z/i,                      2, :narrative_review,  "yellow" ],
      [ /\A(editorial|comment)\z/i,         1, :editorial_comment, "orange" ],
      [ /\Aletter\z/i,                      1, :letter,            "orange" ]
    ].freeze

    # Observational designs are recorded as MeSH *subject headings*, not as
    # publication types (PubMed tags them only "Journal Article"). When the
    # publication type is generic we refine the design from these headings.
    OBSERVATIONAL_MESH = [
      [ /\Acohort studies\z/i,                                              3, :cohort ],
      [ /\A(prospective studies|longitudinal studies|follow-up studies)\z/i, 3, :cohort ],
      [ /\Aretrospective studies\z/i,                                       3, :retrospective_cohort ],
      [ /\Acase-control studies\z/i,                                        2, :case_control ],
      [ /\Across-sectional studies\z/i,                                     2, :cross_sectional ]
    ].freeze

    PREPRINT = { level: 0, type_key: :preprint, color: "red", source_key: :openalex_type }.freeze

    def initialize(openalex_data, crossref_data, pubmed_data = nil)
      @openalex = openalex_data
      @crossref = crossref_data
      @pubmed   = pubmed_data
    end

    def score
      info = detect

      {
        criterion:   I18n.t("scoring.study_type.name"),
        value:       I18n.t("scoring.study_type.types.#{info[:type_key]}"),
        level:       info[:level],
        max_level:   5,
        color:       info[:color],
        source_note: I18n.t("scoring.study_type.sources.#{info[:source_key]}"),
        explanation: I18n.t("scoring.study_type.explanation.l#{info[:level]}")
      }
    end

    private

    def detect
      return PREPRINT if preprint?

      from_pubmed || fallback_from_metadata
    end

    def preprint?
      return true if @openalex&.dig(:type) == "preprint"

      doi = @crossref&.dig(:doi) || @openalex&.dig(:doi) || ""
      PREPRINT_DOI_PREFIXES.any? { |prefix| doi.start_with?(prefix) }
    end

    def from_pubmed
      types = @pubmed&.dig(:publication_types) || []
      mesh  = @pubmed&.dig(:mesh_terms) || []
      return nil if types.empty? && mesh.empty?

      RANKED_TYPES.each do |pattern, level, type_key, color|
        next unless types.any? { |t| t.match?(pattern) }
        return { level: level, type_key: type_key, color: color, source_key: :pubmed_pubtype }
      end

      # Publication type is generic ("Journal Article") — refine the
      # observational design from MeSH headings if present.
      design = observational_from_mesh(mesh)
      return design if design

      types.empty? ? nil : { level: 2, type_key: :original_article, color: "yellow", source_key: :pubmed }
    end

    def observational_from_mesh(mesh)
      OBSERVATIONAL_MESH.each do |pattern, level, type_key|
        next unless mesh.any? { |t| t.match?(pattern) }
        return { level: level, type_key: type_key, color: "yellow", source_key: :pubmed_mesh }
      end
      nil
    end

    def fallback_from_metadata
      case @openalex&.dig(:type)
      when "review"            then { level: 2, type_key: :narrative_review, color: "yellow", source_key: :openalex_type }
      when "editorial"         then { level: 1, type_key: :editorial,        color: "orange", source_key: :openalex_type }
      when "letter"            then { level: 1, type_key: :letter,           color: "orange", source_key: :openalex_type }
      when "article", "report" then { level: 2, type_key: :original_article, color: "yellow", source_key: :openalex_type }
      else
        crossref_fallback
      end
    end

    def crossref_fallback
      if @crossref&.dig(:type) == "journal-article"
        { level: 2, type_key: :journal_article, color: "yellow", source_key: :crossref_type }
      else
        { level: 2, type_key: :undetermined, color: "gray", source_key: :default }
      end
    end
  end
end
