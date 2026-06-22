# A row from the Retraction Watch dataset (CC0, via Crossref). Lets us flag a
# retracted article — with the *reason* — and cross-check a bibliography's DOIs
# offline, without per-reference API calls. Populated by RetractionWatchImporter
# (rake scicheck:retraction_watch:import); everything degrades gracefully when
# the table is empty.
class RetractedPaper < ApplicationRecord
  RETRACTION = "Retraction".freeze

  def self.normalize(doi) = doi.to_s.strip.downcase

  def self.for(doi) = find_by(doi: normalize(doi))

  def self.retracted?(doi)
    where(doi: normalize(doi), nature: RETRACTION).exists?
  end

  # The subset of the given DOIs that are full retractions.
  def self.retracted_dois_among(dois)
    return [] if Array(dois).empty?
    where(doi: Array(dois).map { normalize(_1) }, nature: RETRACTION).pluck(:doi)
  end

  def retraction? = nature == RETRACTION
end
