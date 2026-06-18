require "test_helper"

class PubmedServiceTest < ActiveSupport::TestCase
  XML = <<~XML
    <?xml version="1.0"?>
    <PubmedArticleSet>
     <PubmedArticle>
      <MedlineCitation>
       <Article>
        <PublicationTypeList>
         <PublicationType UI="D016449">Randomized Controlled Trial</PublicationType>
         <PublicationType UI="D016428">Journal Article</PublicationType>
        </PublicationTypeList>
        <DataBankList>
         <DataBank><DataBankName>ClinicalTrials.gov</DataBankName></DataBank>
        </DataBankList>
       </Article>
       <MeshHeadingList>
        <MeshHeading><DescriptorName UI="x">Humans</DescriptorName></MeshHeading>
       </MeshHeadingList>
       <CoiStatement>The authors declare no conflict of interest.</CoiStatement>
      </MedlineCitation>
      <PubmedData>
       <History>
        <PubMedPubDate PubStatus="received"><Year>2024</Year><Month>1</Month><Day>5</Day></PubMedPubDate>
        <PubMedPubDate PubStatus="accepted"><Year>2024</Year><Month>3</Month><Day>10</Day></PubMedPubDate>
       </History>
      </PubmedData>
     </PubmedArticle>
    </PubmedArticleSet>
  XML

  test "parses publication types, data banks, COI and history dates" do
    stub_request(:get, /efetch\.fcgi/).to_return(status: 200, body: XML)
    data = PubmedService.new("40212156").fetch

    assert_includes data[:publication_types], "Randomized Controlled Trial"
    assert_equal [ "ClinicalTrials.gov" ], data[:data_banks]
    assert data[:has_coi_statement]
    assert_includes data[:mesh_terms], "Humans"
    assert_equal Date.new(2024, 1, 5), data[:received_date]
    assert_equal Date.new(2024, 3, 10), data[:accepted_date]
  end

  test "returns nil for a blank or non-numeric pmid without any HTTP" do
    assert_nil PubmedService.new(nil).fetch
    assert_nil PubmedService.new("abc").fetch
  end

  test "returns nil on an upstream error" do
    stub_request(:get, /efetch\.fcgi/).to_return(status: 500)
    assert_nil PubmedService.new("123").fetch
  end

  test "returns nil on malformed XML instead of raising" do
    stub_request(:get, /efetch\.fcgi/).to_return(status: 200, body: "<PubmedArticle><unclosed>")
    assert_nil PubmedService.new("123").fetch
  end

  test "handles a history date with a missing Year element" do
    xml = <<~XML
      <PubmedArticleSet><PubmedArticle><MedlineCitation><Article>
      <PublicationTypeList><PublicationType>Journal Article</PublicationType></PublicationTypeList>
      </Article></MedlineCitation><PubmedData><History>
      <PubMedPubDate PubStatus="received"><Month>3</Month><Day>2</Day></PubMedPubDate>
      </History></PubmedData></PubmedArticle></PubmedArticleSet>
    XML
    stub_request(:get, /efetch\.fcgi/).to_return(status: 200, body: xml)
    data = PubmedService.new("123").fetch
    assert_nil data[:received_date]
  end
end
