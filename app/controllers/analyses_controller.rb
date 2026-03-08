class AnalysesController < ApplicationController
  def new
  end

  def create
    doi = params[:doi].to_s.strip

    if doi.blank?
      flash[:alert] = "Veuillez entrer un DOI."
      return redirect_to new_analysis_path
    end

    # Normalise le DOI : accepte les URLs doi.org, le prefixe "DOI:" ou le DOI brut
    doi = doi.gsub(%r{https?://(dx\.)?doi\.org/}i, "")
             .gsub(/\ADOI:\s*/i, "")
             .strip

    # Appels API en parallele pour minimiser le temps d'attente
    crossref_data = nil
    openalex_data = nil
    pubpeer_data  = nil

    threads = [
      Thread.new { crossref_data = CrossrefService.new(doi).fetch },
      Thread.new { openalex_data = OpenalexService.new(doi).fetch },
      Thread.new { pubpeer_data  = PubpeerService.new(doi).fetch }
    ]
    threads.each(&:join)

    if crossref_data.nil? && openalex_data.nil?
      flash[:alert] = "DOI introuvable. Verifiez le format (ex: 10.1097/MS9.0000000000003127)."
      return redirect_to new_analysis_path
    end

    # Calcul des scores
    scores = {
      study_type:      Scoring::StudyType.new(openalex_data, crossref_data).score,
      review_pedigree: Scoring::ReviewPedigree.new(openalex_data).score,
      review_process:  Scoring::ReviewProcess.new(crossref_data).score,
      open_science:    Scoring::OpenScience.new(crossref_data).score,
      pubpeer:         Scoring::PubpeerCheck.new(pubpeer_data).score
    }

    @result = Scoring::Aggregator.new(scores).aggregate
    @meta   = build_meta(crossref_data, openalex_data, doi)

    render :show
  end

  def show
    # En production, on pourrait charger un resultat cache ici
    redirect_to new_analysis_path
  end

  private

  def build_meta(crossref, openalex, doi)
    {
      doi:          doi,
      title:        crossref&.dig(:title) || openalex&.dig(:journal_name),
      abstract:     crossref&.dig(:abstract),
      authors:      crossref&.dig(:authors) || [],
      journal:      crossref&.dig(:journal) || openalex&.dig(:journal_name),
      published:    crossref&.dig(:published_date) || openalex&.dig(:publication_date),
      url:          crossref&.dig(:url) || openalex&.dig(:oa_url),
      topics:       openalex&.dig(:topics) || []
    }
  end
end
