require "base64"
require "digest"

class AnalysesController < ApplicationController
  # A well-formed DOI, used both to extract and to validate the id from the URL.
  DOI_FORMAT = %r{\A10\.\d{4,9}/\S+\z}

  def new
  end

  # POST: resolve the DOI, run (and cache) the analysis, then redirect to a
  # shareable result URL (Post/Redirect/Get — a refresh never re-submits).
  def create
    doi = DoiResolver.new(params[:doi]).resolve&.downcase

    if doi.blank? || !doi.match?(DOI_FORMAT)
      return redirect_to new_analysis_path, alert: t("flash.invalid_doi")
    end

    if load_or_run(doi).nil?
      return redirect_to new_analysis_path, alert: t("flash.not_found", doi: doi)
    end

    redirect_to analysis_path(encode_id(doi))
  end

  # GET: render a (possibly shared/bookmarked) result. Recomputes on a cache
  # miss, so the link keeps working after the cache expires.
  def show
    doi = decode_id(params[:id])
    return redirect_to(new_analysis_path, alert: t("flash.invalid_link")) if doi.nil?

    payload = load_or_run(doi)
    return redirect_to(new_analysis_path, alert: t("flash.expired")) if payload.nil?

    @result = payload[:result]
    @meta   = payload[:meta]
  end

  private

  def load_or_run(doi)
    Rails.cache.fetch(cache_key(doi), expires_in: Scicheck::Config::ANALYSIS_CACHE_TTL, skip_nil: true) do
      AnalysisRunner.new(doi).call
    end
  end

  def cache_key(doi)
    "analysis/v2/#{Digest::SHA256.hexdigest(doi)}"
  end

  def encode_id(doi)
    Base64.urlsafe_encode64(doi, padding: false)
  end

  # Only accept ids that decode to a well-formed DOI (prevents arbitrary input
  # reaching the cache layer / runner).
  def decode_id(id)
    doi = Base64.urlsafe_decode64(id.to_s)
    doi.match?(DOI_FORMAT) ? doi : nil
  rescue ArgumentError
    nil
  end
end
