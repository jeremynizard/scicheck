require "base64"

module Api
  module V1
    # Read-only JSON API for the browser extension: given a DOI, returns the
    # score (or a pending/not-found state). CORS is configured in cors.rb.
    class AnalysesController < ApplicationController
      def show
        doi = DoiResolver.new(params[:doi]).resolve&.downcase

        if doi.blank? || !doi.match?(::AnalysesController::DOI_FORMAT)
          return render json: { error: "invalid_doi" }, status: :unprocessable_entity
        end

        case AnalysisJob.state(doi, I18n.locale)
        when "ready"
          render json: serialize(doi, Analysis.for(doi, I18n.locale))
        when "not_found"
          render json: { state: "not_found", doi: doi }, status: :not_found
        when "error"
          render json: { state: "error", doi: doi }, status: :bad_gateway
        else
          AnalysisJob.enqueue(doi, I18n.locale)
          render json: { state: "pending", doi: doi, url: result_url(doi) }, status: :accepted
        end
      end

      private

      def serialize(doi, record)
        result = record.result
        meta   = record.meta
        {
          state:     "ready",
          doi:       doi,
          url:       result_url(doi),
          title:     meta[:title],
          retracted: meta[:retracted] == true,
          grade:     result[:grade],
          score:     result[:global_score],
          color:     result[:color],
          summary:   result[:summary],
          criteria:  result[:criteria].values.map do |c|
            { name: c[:criterion], value: c[:value], level: c[:level], max_level: c[:max_level], color: c[:color] }
          end
        }
      end

      def result_url(doi)
        analysis_url(Base64.urlsafe_encode64(doi, padding: false))
      end
    end
  end
end
