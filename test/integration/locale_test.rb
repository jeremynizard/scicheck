require "test_helper"

class LocaleTest < ActionDispatch::IntegrationTest
  test "home page renders in English by default" do
    get new_analysis_path
    assert_response :success
    assert_select "h1", text: "Evaluate the quality of a scientific article"
  end

  test "home page renders in French when ?locale=fr is given" do
    get new_analysis_path(locale: :fr)
    assert_response :success
    assert_select "h1", text: "Évaluez la qualité d'un article scientifique"
    assert_select ".doi-hint", text: /Colle un DOI/ # French hint (vs English "Paste")
  end

  test "the chosen locale persists across requests via the session" do
    get new_analysis_path(locale: :fr)
    get new_analysis_path # no locale param this time
    assert_select "h1", text: "Évaluez la qualité d'un article scientifique"
  end

  test "an unknown locale falls back to the default" do
    get new_analysis_path(locale: :zz)
    assert_response :success
    assert_select "h1", text: "Evaluate the quality of a scientific article"
  end
end
