require "test_helper"

class LocaleTest < ActionDispatch::IntegrationTest
  test "the site renders in American English" do
    get new_analysis_path
    assert_response :success
    assert_select "h1", text: "Evaluate the quality of a scientific article"
    assert_select ".doi-hint", text: /Paste a DOI/
  end

  test "there is no language switcher (English only)" do
    get new_analysis_path
    assert_select ".lang-switch", false
  end

  test "a locale param is ignored — the site stays English" do
    get new_analysis_path(locale: :fr)
    assert_response :success
    assert_select "h1", text: "Evaluate the quality of a scientific article"
  end
end
