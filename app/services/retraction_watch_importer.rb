require "csv"

# Imports the Retraction Watch dataset (CC0) into the retracted_papers table.
# Source defaults to Crossref Labs' CSV endpoint, or pass a local file path.
# Run via `rake scicheck:retraction_watch:import`.
class RetractionWatchImporter
  include HttpClient

  DEFAULT_SOURCE = "https://api.labs.crossref.org/data/retractionwatch?#{Scicheck::Config::CONTACT_EMAIL}".freeze
  BATCH_SIZE     = 1000

  # Returns the number of rows imported/updated, or nil if the source was unreadable.
  def import(source = DEFAULT_SOURCE)
    csv = read(source)
    return nil if csv.nil?

    now  = Time.current
    rows = []
    count = 0

    CSV.parse(csv, headers: true) do |row|
      record = row_to_attributes(row, now)
      next if record.nil?

      rows << record
      if rows.size >= BATCH_SIZE
        flush(rows)
        count += rows.size
        rows = []
      end
    end

    unless rows.empty?
      flush(rows)
      count += rows.size
    end

    count
  end

  private

  def read(source)
    if source.to_s.match?(%r{\Ahttps?://}i)
      response = http_get(URI(source), headers: { "Accept" => "text/csv" }, read_timeout: 60)
      response.is_a?(Net::HTTPSuccess) ? response.body : nil
    elsif File.exist?(source.to_s)
      File.read(source)
    end
  rescue *NETWORK_ERRORS => e
    log_http_failure(source, e)
    nil
  end

  def row_to_attributes(row, now)
    doi = RetractedPaper.normalize(row["OriginalPaperDOI"])
    return nil if doi.empty? || doi == "unavailable"

    {
      doi:             doi,
      nature:          row["RetractionNature"].to_s.strip.presence,
      reason:          clean_reason(row["Reason"]),
      retraction_date: parse_date(row["RetractionDate"]),
      title:           row["Title"].to_s.strip.presence,
      created_at:      now,
      updated_at:      now
    }
  end

  # Retraction Watch encodes reasons as "+Reason A;+Reason B;".
  def clean_reason(raw)
    return nil if raw.blank?
    raw.split(";").map { |r| r.gsub(/\A\s*\+/, "").strip }.reject(&:empty?).join(", ").presence
  end

  def parse_date(raw)
    return nil if raw.blank?
    stamp = raw.to_s.split(" ").first # drop any "0:00" time suffix
    Date.strptime(stamp, "%m/%d/%Y")
  rescue ArgumentError, TypeError
    Date.parse(raw) rescue nil
  end

  def flush(rows)
    RetractedPaper.upsert_all(rows, unique_by: :doi)
  end
end
