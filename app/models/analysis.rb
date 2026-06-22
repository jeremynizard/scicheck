# A durably-stored analysis result, keyed by DOI.
#
# Replaces the previous in-process Rails.cache so that shareable result URLs
# survive restarts and we keep a history (for analytics). The full payload
# (exactly what AnalysisRunner returns — symbol keys, Date objects) is stored
# via YAML so it round-trips unchanged; the headline score/grade are also
# denormalized into columns for cheap querying.
class Analysis < ApplicationRecord
  serialize :payload, coder: YAML, type: Hash

  validates :doi, presence: true, uniqueness: { scope: :locale }

  def result = payload[:result]
  def meta   = payload[:meta]

  def fresh?(ttl = Scicheck::Config::ANALYSIS_CACHE_TTL)
    computed_at.present? && computed_at > Time.current - ttl
  end

  # Results carry translated text and a localized AI summary, so they are keyed
  # by (DOI, locale): a French viewer never sees an English-computed result.
  def self.for(doi, locale)
    find_by(doi: doi, locale: locale.to_s)
  end

  # Upsert the record for a (DOI, locale) from a freshly-computed payload.
  def self.store(doi, locale, payload)
    record = find_or_initialize_by(doi: doi, locale: locale.to_s)
    record.payload      = payload
    record.global_score = payload.dig(:result, :global_score)
    record.grade        = payload.dig(:result, :grade)
    record.computed_at  = Time.current
    record.accessed_at  = Time.current
    record.save!
    record
  end
end
