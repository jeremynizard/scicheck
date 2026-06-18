require "base64"

class AnalysesController < ApplicationController
  # A well-formed DOI, used both to extract and to validate the id from the URL.
  DOI_FORMAT = %r{\A10\.\d{4,9}/\S+\z}

  def new
  end

  # POST: resolve the DOI, enqueue the (background) analysis, then redirect to a
  # shareable result URL. The heavy work runs async; the result page polls.
  def create
    doi = DoiResolver.new(params[:doi]).resolve&.downcase

    if doi.blank? || !doi.match?(DOI_FORMAT)
      return redirect_to new_analysis_path, alert: t("flash.invalid_doi")
    end

    AnalysisJob.enqueue(doi, I18n.locale)
    redirect_to analysis_path(encode_id(doi))
  end

  # GET: render the result if ready, a "not found" redirect if the analysis came
  # back empty, otherwise a pending page that polls #status. Also (re)enqueues
  # for shared/bookmarked links that arrive cold.
  def show
    doi = decode_id(params[:id])
    return redirect_to(new_analysis_path, alert: t("flash.invalid_link")) if doi.nil?

    case AnalysisJob.state(doi, I18n.locale)
    when "ready"
      record = Analysis.for(doi, I18n.locale)
      record.update_column(:accessed_at, Time.current)
      @result, @meta, @ai = record.result, record.meta, record.payload[:ai]
      render :show
    when "not_found", "error"
      redirect_to new_analysis_path, alert: t("flash.not_found", doi: doi)
    else
      AnalysisJob.enqueue(doi, I18n.locale)
      @status_url = analysis_status_path(params[:id])
      render :pending
    end
  end

  # Polled by the pending page. Returns the current job state as JSON.
  def status
    doi = decode_id(params[:id])
    state = doi ? AnalysisJob.state(doi, I18n.locale) : "error"
    render json: { state: state }
  end

  private

  def encode_id(doi)
    Base64.urlsafe_encode64(doi, padding: false)
  end

  # Only accept ids that decode to a well-formed DOI (prevents arbitrary input
  # reaching the job/runner).
  def decode_id(id)
    doi = Base64.urlsafe_decode64(id.to_s)
    doi.match?(DOI_FORMAT) ? doi : nil
  rescue ArgumentError
    nil
  end
end
