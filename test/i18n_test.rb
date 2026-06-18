require "test_helper"

class I18nTest < ActiveSupport::TestCase
  def flatten_keys(hash, prefix = "")
    hash.flat_map do |k, v|
      key = prefix.empty? ? k.to_s : "#{prefix}.#{k}"
      v.is_a?(Hash) ? flatten_keys(v, key) : [ key ]
    end
  end

  def load_locale(name)
    YAML.load_file(Rails.root.join("config", "locales", "#{name}.yml")).fetch(name)
  end

  test "en and fr define exactly the same set of keys" do
    en = flatten_keys(load_locale("en")).sort
    fr = flatten_keys(load_locale("fr")).sort
    assert_equal en, fr, "Locale key mismatch (missing translations): #{(en - fr) | (fr - en)}"
  end

  test "scoring output is localized" do
    pm = { publication_types: [ "Meta-Analysis" ] }
    assert_equal "Meta-analysis", I18n.with_locale(:en) { Scoring::StudyType.new(nil, nil, pm).score[:value] }
    assert_equal "Méta-analyse", I18n.with_locale(:fr) { Scoring::StudyType.new(nil, nil, pm).score[:value] }
  end

  test "aggregator summary is localized" do
    scores = { study_type: { level: 5, max_level: 5 } }
    fr = I18n.with_locale(:fr) { Scoring::Aggregator.new(scores).aggregate[:summary] }
    assert_match(/qualité méthodologique/, fr)
  end
end
