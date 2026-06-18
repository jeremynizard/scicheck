module Scoring
  # Transparency / open-science signals.
  #
  # Combines three sources:
  #   1. PubMed registered data banks (ClinicalTrials.gov, GEO, Dryad, ...);
  #   2. a conflict-of-interest statement (PubMed);
  #   3. text patterns in the abstract (Crossref, with OpenAlex as fallback).
  class OpenScience
    # Label => matcher. Labels are proper nouns / shown verbatim (not translated).
    DATA_PATTERNS = {
      "GitHub"             => /github\.com/i,
      "GitLab"             => /gitlab\.com/i,
      "Zenodo"             => /zenodo\.org/i,
      "OSF"                => %r{osf\.io}i,
      "Figshare"           => /figshare/i,
      "Dryad"              => /dryad/i,
      "ClinicalTrials.gov" => /clinicaltrials\.gov/i,
      "PROSPERO"           => /prospero/i,
      "Data availability"  => /data\s+availab/i,
      "Data sharing"       => /data\s+sharing/i,
      "Open data"          => /open\s+data/i
    }.freeze

    def initialize(crossref_data, pubmed_data = nil, openalex_data = nil)
      @crossref = crossref_data
      @pubmed   = pubmed_data
      @openalex = openalex_data
    end

    def score
      detected = collect_signals
      level, color = compute(detected.size)

      {
        criterion:   I18n.t("scoring.open_science.name"),
        value:       value_for(detected),
        level:       level,
        max_level:   2,
        color:       color,
        explanation: I18n.t("scoring.open_science.l#{level}"),
        detected:    detected
      }
    end

    private

    def collect_signals
      signals = []

      Array(@pubmed&.dig(:data_banks)).each { |name| signals << registered(name) }
      signals << I18n.t("scoring.open_science.coi") if @pubmed&.dig(:has_coi_statement)

      text = abstract_text
      DATA_PATTERNS.each do |label, pattern|
        next unless text.match?(pattern)
        # Avoid double-counting a registry already captured as a data bank.
        next if signals.include?(registered(label))
        signals << label
      end

      signals.uniq
    end

    def registered(name)
      I18n.t("scoring.open_science.registered", name: name)
    end

    def abstract_text
      (@crossref&.dig(:abstract).presence || @openalex&.dig(:abstract)).to_s
    end

    def value_for(detected)
      return I18n.t("scoring.open_science.value_none") if detected.empty?
      I18n.t("scoring.open_science.value", count: detected.size)
    end

    def compute(count)
      case count
      when 0 then [ 0, "orange" ]
      when 1 then [ 1, "yellow" ]
      else        [ 2, "green" ]
      end
    end
  end
end
