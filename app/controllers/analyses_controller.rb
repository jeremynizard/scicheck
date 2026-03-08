class AnalysesController < ApplicationController
  def new
  end

  def create
    doi = params[:doi].to_s.strip

    if doi.blank?
      flash[:alert] = "Please enter a DOI."
      return redirect_to new_analysis_path
    end

    # Normalize DOI: accepts doi.org URLs, "DOI:" prefix, or raw DOI
    doi = doi.gsub(%r{https?://(dx\.)?doi\.org/}i, "")
             .gsub(/\ADOI:\s*/i, "")
             .strip

    # Parallel API calls to minimize wait time
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
      flash[:alert] = "DOI not found. Please check the format (e.g. 10.1097/MS9.0000000000003127)."
      return redirect_to new_analysis_path
    end

    # Dependent calls (need references + authorships from first batch)
    retraction_data = nil
    author_profiles = nil

    dependent_threads = [
      Thread.new { retraction_data = OpenalexRetractionService.new(crossref_data&.dig(:references)).fetch },
      Thread.new { author_profiles = OpenalexAuthorService.new(openalex_data&.dig(:authorships)).fetch }
    ]
    dependent_threads.each(&:join)

    # Score computation
    scores = {
      study_type:           Scoring::StudyType.new(openalex_data, crossref_data).score,
      review_pedigree:      Scoring::ReviewPedigree.new(openalex_data).score,
      review_process:       Scoring::ReviewProcess.new(crossref_data).score,
      open_science:         Scoring::OpenScience.new(crossref_data).score,
      pubpeer:              Scoring::PubpeerCheck.new(pubpeer_data).score,
      citation_profile:     Scoring::CitationProfile.new(openalex_data).score,
      retracted_references: Scoring::RetractedReferences.new(retraction_data).score,
      author_track_record:  Scoring::AuthorTrackRecord.new(author_profiles).score
    }

    @result = Scoring::Aggregator.new(scores).aggregate
    @meta   = build_meta(crossref_data, openalex_data, doi, author_profiles)

    render :show
  end

  def show
    # In production, we could load a cached result here
    redirect_to new_analysis_path
  end

  private

  def build_meta(crossref, openalex, doi, author_profiles = nil)
    authors = crossref&.dig(:authors) || []

    # Enrich authors with OpenAlex profiles if available
    if author_profiles&.any?
      profile_map = author_profiles.index_by { |p| p[:name] }
      authors = authors.map do |a|
        profile = profile_map[a[:name]]
        if profile
          a.merge(h_index: profile[:h_index], institutions: profile[:institutions])
        else
          a
        end
      end
    end

    {
      doi:          doi,
      title:        crossref&.dig(:title) || openalex&.dig(:journal_name),
      abstract:     crossref&.dig(:abstract),
      authors:      authors,
      journal:      crossref&.dig(:journal) || openalex&.dig(:journal_name),
      published:    crossref&.dig(:published_date) || openalex&.dig(:publication_date),
      url:          crossref&.dig(:url) || openalex&.dig(:oa_url),
      topics:       openalex&.dig(:topics) || [],
      oa_status:    openalex&.dig(:oa_status)
    }
  end
end
