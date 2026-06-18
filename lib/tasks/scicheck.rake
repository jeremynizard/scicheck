namespace :scicheck do
  # Regression / validation harness: scores a curated set of well-known DOIs
  # against expectations and prints a pass/fail table. This is the groundwork
  # for empirical calibration — you cannot tune weights/thresholds without first
  # measuring the scorer against ground truth.
  #
  # Hits the live (free) APIs, so run it manually — it is NOT part of CI.
  #   bin/rails scicheck:validate
  #
  # Each case asserts the detected study-type level and a coarse grade band.
  CASES = [
    { doi: "10.1056/NEJMoa2021436",            note: "RCT (RECOVERY dexamethasone)",  level: 4,      grades: %w[A B] },
    { doi: "10.1097/MS9.0000000000003127",     note: "Narrative review",              level: 2,      grades: %w[A B C] },
    { doi: "10.1016/S0140-6736(97)11096-0",    note: "Retracted (Wakefield 1998)",    retracted: true, grades: %w[E] },
    { doi: "10.1136/bmj.39489.470347.AD",      note: "Guideline / analysis (BMJ)",    grades: %w[A B C] }
  ].freeze

  desc "Validate the scorer against a curated set of known DOIs (live APIs)"
  task validate: :environment do
    rows = []
    failures = 0

    CASES.each do |c|
      out = AnalysisRunner.new(c[:doi]).call
      if out.nil?
        rows << [ c[:note], "NOT FOUND", "-", "-", "FAIL" ]
        failures += 1
        next
      end

      st        = out[:result][:criteria][:study_type]
      grade     = out[:result][:grade]
      retracted = out[:meta][:retracted]

      ok = true
      ok &&= (st[:level] == c[:level])      if c.key?(:level)
      ok &&= (retracted == c[:retracted])   if c.key?(:retracted)
      ok &&= c[:grades].include?(grade)     if c.key?(:grades)
      failures += 1 unless ok

      rows << [
        c[:note],
        "L#{st[:level]} #{st[:value]}".slice(0, 34),
        "#{out[:result][:global_score]} (#{grade})",
        retracted ? "retracted" : "-",
        ok ? "PASS" : "FAIL"
      ]
    end

    fmt = "%-32s %-36s %-12s %-11s %-5s"
    puts format(fmt, "CASE", "DETECTED STUDY TYPE", "SCORE", "FLAG", "")
    puts "-" * 100
    rows.each { |r| puts format(fmt, *r) }
    puts "-" * 100
    puts "#{CASES.size - failures}/#{CASES.size} passed"
    abort("Validation failures: #{failures}") if failures.positive?
  end
end
