# Runs an analysis in the background (ActiveJob :async adapter — a thread pool,
# no Redis/DB queue needed) so the request returns immediately and the page
# polls for completion.
#
# Lifecycle state is tracked in Rails.cache:
#   idle → pending → (ready | not_found | error)
# "ready" is derived from a fresh Analysis row rather than the cache, so a
# durably-stored result is always considered ready.
class AnalysisJob < ApplicationJob
  queue_as :default

  STATE_TTL          = 3.minutes
  TERMINAL_STATE_TTL = 5.minutes

  def self.state_key(doi, locale) = "analysis_state/#{locale}/#{doi}"

  def self.state(doi, locale)
    return "ready" if Analysis.for(doi, locale)&.fresh?
    Rails.cache.read(state_key(doi, locale)) || "idle"
  end

  # Enqueue unless a fresh result already exists or a job is already running.
  def self.enqueue(doi, locale)
    return if %w[ready pending].include?(state(doi, locale))
    Rails.cache.write(state_key(doi, locale), "pending", expires_in: STATE_TTL)
    perform_later(doi, locale.to_s)
  end

  def perform(doi, locale)
    payload = AnalysisRunner.new(doi, locale: locale).call

    if payload
      Analysis.store(doi, locale, payload)
      Rails.cache.delete(self.class.state_key(doi, locale)) # "ready" now derives from the row
    else
      Rails.cache.write(self.class.state_key(doi, locale), "not_found", expires_in: TERMINAL_STATE_TTL)
    end
  rescue StandardError => e
    Rails.logger.error("[AnalysisJob] #{e.class}: #{e.message}") if defined?(Rails)
    Rails.cache.write(self.class.state_key(doi, locale), "error", expires_in: 2.minutes)
  end
end
