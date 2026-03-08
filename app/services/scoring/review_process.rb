module Scoring
  class ReviewProcess
    def initialize(crossref_data)
      @data = crossref_data
    end

    def score
      received = @data&.dig(:received_date)
      accepted = @data&.dig(:accepted_date)

      if received.nil? || accepted.nil?
        return {
          criterion:   "Review rigor",
          value:       "Data unavailable",
          level:       nil,
          max_level:   3,
          color:       "gray",
          explanation: "Submission and acceptance dates are not published by this publisher."
        }
      end

      days = (accepted - received).to_i
      level, color, detail = compute(days)

      {
        criterion:   "Review rigor",
        value:       "#{days}-day review",
        level:       level,
        max_level:   3,
        color:       color,
        explanation: detail,
        days:        days
      }
    end

    private

    def compute(days)
      if days < 21
        [ 0, "red",    "Accepted in under 3 weeks. Possible sign of a journal without serious peer review." ]
      elsif days < 60
        [ 1, "orange", "Fast review (#{days} days). Possible but on the low end for rigorous peer review." ]
      elsif days <= 180
        [ 3, "green",  "Normal review duration (#{days} days). Sign of a serious review process." ]
      else
        [ 2, "yellow", "Long review (#{days} days). May indicate major revisions or a slow process." ]
      end
    end
  end
end
