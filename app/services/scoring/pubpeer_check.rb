module Scoring
  class PubpeerCheck
    def initialize(pubpeer_data)
      @data = pubpeer_data
    end

    def score
      return unavailable if @data.nil?

      if @data[:has_comments]
        {
          criterion:     "Post-publication flags",
          value:         "#{@data[:comment_count]} comment(s) on PubPeer",
          level:         0,
          max_level:     1,
          color:         "red",
          explanation:   "This article has been flagged on PubPeer by researchers. " \
                         "This may indicate errors, suspicious images, or methodological issues.",
          pubpeer_url:   @data[:url]
        }
      else
        {
          criterion:     "Post-publication flags",
          value:         "No PubPeer flags",
          level:         1,
          max_level:     1,
          color:         "green",
          explanation:   "No critical comments have been reported on PubPeer for this article. " \
                         "Note: absence of flags does not guarantee absence of problems.",
          pubpeer_url:   nil
        }
      end
    end

    private

    def unavailable
      {
        criterion:   "Post-publication flags",
        value:       "Data unavailable",
        level:       nil,
        max_level:   1,
        color:       "gray",
        explanation: "Unable to contact PubPeer for this article."
      }
    end
  end
end
