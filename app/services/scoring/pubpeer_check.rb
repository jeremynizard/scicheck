module Scoring
  class PubpeerCheck
    def initialize(pubpeer_data)
      @data = pubpeer_data
    end

    def score
      return unavailable if @data.nil?

      if @data[:has_comments]
        {
          criterion:     "Signalements post-publication",
          value:         "#{@data[:comment_count]} commentaire(s) sur PubPeer",
          level:         0,
          max_level:     1,
          color:         "red",
          explanation:   "Cet article a ete signale sur PubPeer par des chercheurs. " \
                         "Cela peut indiquer des erreurs, des images suspectes ou des problemes methodologiques.",
          pubpeer_url:   @data[:url]
        }
      else
        {
          criterion:     "Signalements post-publication",
          value:         "Aucun signalement PubPeer",
          level:         1,
          max_level:     1,
          color:         "green",
          explanation:   "Aucun commentaire critique n'a ete signale sur PubPeer pour cet article. " \
                         "Note : l'absence de signalement ne garantit pas l'absence de problemes.",
          pubpeer_url:   nil
        }
      end
    end

    private

    def unavailable
      {
        criterion:   "Signalements post-publication",
        value:       "Donnees indisponibles",
        level:       nil,
        max_level:   1,
        color:       "gray",
        explanation: "Impossible de contacter PubPeer pour cet article."
      }
    end
  end
end
