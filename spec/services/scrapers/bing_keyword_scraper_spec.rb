require "rails_helper"
require "nokogiri"

RSpec.describe Scrapers::BingKeywordScraper, type: :service do
  describe "#call" do
    context "when page has results" do
      it "extracts both ads and organic results" do
        mock_browser, mock_page = create_mock_browser_with_mocks

        # Mock organic results
        allow(mock_page).to receive(:css).with("#b_results > li.b_algo h2 a").and_return([
          double("link",
            attribute: double(to_s: "https://example.com"),
            text: "Example Result",
            parent: nil)
        ])

        # Mock ads
        ad_item = double("ad_item")
        allow(ad_item).to receive(:at_css).with("h2.b_topTitleAd a, .mma_smallcard_title a, .smallmma_ad_title a, h2 a, h3 a, .b_title a").and_return(
          double("ad_link",
            attribute: double(to_s: "https://ad.example.com"),
            text: "Test Ad")
        )
        ad_container = double("ad_container")
        allow(ad_container).to receive(:css).with("li").and_return([ ad_item ])
        allow(mock_page).to receive(:css).with("li.b_ad").and_return([ ad_container ])

        scraper = described_class.new(browser: mock_browser)
        stub_scraper_delays(scraper)

        result = scraper.call("ruby programming", max_results: 10)

        expect(result).to be_a(Scrapers::BingKeywordScraper::Result)
        expect(result.html).to be_present
        expect(result.result_url).to eq("https://www.bing.com/search?q=test")
        expect(result.ads).to be_an(Array)
        expect(result.links).to be_an(Array)
      end

      it "calls progress callback if provided" do
        mock_browser, mock_page = create_mock_browser_with_mocks

        allow(mock_page).to receive(:css).with("#b_results > li.b_algo h2 a").and_return([
          double("link",
            attribute: double(to_s: "https://example.com"),
            text: "Example Result",
            parent: nil)
        ])

        ad_item = double("ad_item")
        allow(ad_item).to receive(:at_css).and_return(
          double("ad_link",
            attribute: double(to_s: "https://ad.example.com"),
            text: "Test Ad")
        )
        ad_container = double("ad_container")
        allow(ad_container).to receive(:css).with("li").and_return([ ad_item ])
        allow(mock_page).to receive(:css).with("li.b_ad").and_return([ ad_container ])

        scraper = described_class.new(browser: mock_browser)
        stub_scraper_delays(scraper)
        progress_calls = []

        scraper.call("ruby programming", max_results: 10) do |progress_data|
          progress_calls << progress_data
        end

        expect(progress_calls).not_to be_empty
        expect(progress_calls.first).to have_key(:ads)
        expect(progress_calls.first).to have_key(:links)
        expect(progress_calls.first).to have_key(:current_page)
        expect(progress_calls.first).to have_key(:html)
      end
    end

    context "when page has no ads" do
      it "handles missing ads gracefully" do
        mock_browser, mock_page = create_mock_browser_with_mocks

        allow(mock_page).to receive(:at_css).with("li.b_ad").and_raise(Ferrum::TimeoutError.new("Ads not found"))
        allow(mock_page).to receive(:css).with("#b_results > li.b_algo h2 a").and_return([
          double("link",
            attribute: double(to_s: "https://example.com"),
            text: "Example Result",
            parent: nil)
        ])
        allow(mock_page).to receive(:css).with("li.b_ad").and_return([])

        scraper = described_class.new(browser: mock_browser)
        stub_scraper_delays(scraper)

        result = scraper.call("ruby programming", max_results: 10)

        expect(result).to be_a(Scrapers::BingKeywordScraper::Result)
        expect(result.ads).to eq([])
        expect(result.links).to be_an(Array)
      end
    end

    context "when scraping fails" do
      it "raises the error" do
        mock_browser, mock_page = create_mock_browser_with_mocks

        allow(mock_page).to receive(:go_to).and_raise(Ferrum::Error.new("Connection failed"))

        scraper = described_class.new(browser: mock_browser)
        stub_scraper_delays(scraper)

        expect { scraper.call("ruby programming") }.to raise_error(Ferrum::Error, "Connection failed")
      end
    end
  end

  describe "#close" do
    it "quits the browser" do
      mock_browser = instance_double(Ferrum::Browser)
      allow(mock_browser).to receive(:quit)
      scraper = described_class.new(browser: mock_browser)

      scraper.close

      expect(mock_browser).to have_received(:quit)
    end

    it "handles browser quit errors gracefully" do
      mock_browser = instance_double(Ferrum::Browser)
      allow(mock_browser).to receive(:quit).and_raise(StandardError.new("Quit failed"))
      scraper = described_class.new(browser: mock_browser)

      expect { scraper.close }.not_to raise_error
    end
  end

  describe "Result struct" do
    it "calculates ads count correctly" do
      result = Scrapers::BingKeywordScraper::Result.new(
        html: "<html>test</html>",
        ads: [ { "title" => "Ad 1" }, { "title" => "Ad 2" } ],
        links: [ { "title" => "Link 1" } ],
        result_url: "https://example.com"
      )

      expect(result.ads_count).to eq(2)
    end

    it "calculates links count correctly" do
      result = Scrapers::BingKeywordScraper::Result.new(
        html: "<html>test</html>",
        ads: [ { "title" => "Ad 1" } ],
        links: [ { "title" => "Link 1" }, { "title" => "Link 2" }, { "title" => "Link 3" } ],
        result_url: "https://example.com"
      )

      expect(result.links_count).to eq(3)
    end

    it "handles nil ads and links" do
      result = Scrapers::BingKeywordScraper::Result.new(ads: nil, links: nil)

      expect(result.ads_count).to eq(0)
      expect(result.links_count).to eq(0)
    end
  end

  # HTML Parsing Tests - merged from bing_keyword_scraper_html_parsing_spec.rb
  describe "#extract_ads and #extract_links" do
    before do
      # Define mock classes for testing HTML parsing
      noko_element_class = Class.new do
        def initialize(element)
          @element = element
        end

        def attribute(name)
          AttributeWrapper.new(@element[name])
        end

        def text
          @element.text.strip
        end

        def at_css(selector)
          child = @element.at_css(selector)
          child ? self.class.new(child) : nil
        end

        def css(selector)
          @element.css(selector).map { |el| self.class.new(el) }
        end

        def parent
          parent_el = @element.parent
          parent_el ? self.class.new(parent_el) : nil
        end
      end

      attribute_wrapper_class = Class.new do
        def initialize(value)
          @value = value
        end

        def to_s
          @value.to_s
        end
      end

      stub_const("NokoElement", noko_element_class)
      stub_const("AttributeWrapper", attribute_wrapper_class)
    end

    describe "when parsing HTML with ads" do
      it "extracts ads from real HTML" do
        # Arrange
        scraper = described_class.new(headless: true)
        ads_html = File.read(Rails.root.join("spec/fixtures/files/with-ads.html"))
        mock_page = create_html_mock_page(ads_html)

        # Act
        ads = scraper.send(:extract_ads, mock_page, 1)

        # Assert
        expect(ads).to be_an(Array)
        expect(ads.length).to be > 0

        first_ad = ads.first
        expect(first_ad).to have_key(:title)
        expect(first_ad).to have_key(:url)
        expect(first_ad).to have_key(:page)
        expect(first_ad[:page]).to eq(1)
        expect(first_ad[:title]).to be_a(String)
        expect(first_ad[:url]).to start_with("http")

        # Cleanup
        scraper.close
      end

      it "extracts organic links from real HTML" do
        # Arrange
        scraper = described_class.new(headless: true)
        ads_html = File.read(Rails.root.join("spec/fixtures/files/with-ads.html"))
        mock_page = create_html_mock_page(ads_html)

        # Act
        links = scraper.send(:extract_links, mock_page, 1)

        # Assert
        expect(links).to be_an(Array)
        expect(links.length).to be > 0

        first_link = links.first
        expect(first_link).to have_key(:title)
        expect(first_link).to have_key(:url)
        expect(first_link).to have_key(:page)
        expect(first_link[:page]).to eq(1)
        expect(first_link[:title]).to be_a(String)
        expect(first_link[:url]).to start_with("http")

        # Cleanup
        scraper.close
      end
    end

    describe "when parsing HTML without ads" do
      it "extracts no ads from HTML without ads" do
        # Arrange
        scraper = described_class.new(headless: true)
        no_ads_html = File.read(Rails.root.join("spec/fixtures/files/without-ads.html"))
        mock_page = create_html_mock_page(no_ads_html)

        # Act
        ads = scraper.send(:extract_ads, mock_page, 1)

        # Assert
        expect(ads).to be_an(Array)
        expect(ads).to be_empty

        # Cleanup
        scraper.close
      end

      it "still extracts organic links from HTML without ads" do
        # Arrange
        scraper = described_class.new(headless: true)
        no_ads_html = File.read(Rails.root.join("spec/fixtures/files/without-ads.html"))
        mock_page = create_html_mock_page(no_ads_html)

        # Act
        links = scraper.send(:extract_links, mock_page, 1)

        # Assert
        expect(links).to be_an(Array)
        expect(links.length).to be > 0

        first_link = links.first
        expect(first_link).to have_key(:title)
        expect(first_link).to have_key(:url)
        expect(first_link).to have_key(:page)
        expect(first_link[:page]).to eq(1)

        # Cleanup
        scraper.close
      end
    end

    describe "edge cases" do
      context "when HTML has ads with various invalid links" do
        it "filters out invalid ads" do
          # Arrange
          scraper = described_class.new(headless: true)
          realistic_html = <<~HTML
            <html>
              <body>
                <div id="b_results">
                  <li class="b_ad">
                    <ul>
                      <li>
                        <h2 class="b_topTitleAd"><a href="">Empty URL Ad</a></h2>
                      </li>
                      <li>
                        <h2 class="b_topTitleAd"><a href="javascript:void(0)">JavaScript Ad</a></h2>
                      </li>
                      <li>
                        <h2 class="b_topTitleAd"><a href="https://good-ad.com">Good Ad</a></h2>
                      </li>
                    </ul>
                  </li>
                  <li class="b_algo">
                    <h2><a href="https://organic-result.com">Organic Result</a></h2>
                  </li>
                </div>
              </body>
            </html>
          HTML
          mock_page = create_html_mock_page(realistic_html)

          # Act
          ads = scraper.send(:extract_ads, mock_page, 1)

          # Assert
          expect(ads).to be_an(Array)
          expect(ads.length).to eq(1)
          expect(ads.first[:url]).to eq("https://good-ad.com")
          expect(ads.first[:title]).to eq("Good Ad")

          # Cleanup
          scraper.close
        end

        it "extracts organic links normally" do
          # Arrange
          scraper = described_class.new(headless: true)
          realistic_html = <<~HTML
            <html>
              <body>
                <div id="b_results">
                  <li class="b_ad">
                    <ul>
                      <li>
                        <h2 class="b_topTitleAd"><a href="">Empty URL Ad</a></h2>
                      </li>
                      <li>
                        <h2 class="b_topTitleAd"><a href="javascript:void(0)">JavaScript Ad</a></h2>
                      </li>
                      <li>
                        <h2 class="b_topTitleAd"><a href="https://good-ad.com">Good Ad</a></h2>
                      </li>
                    </ul>
                  </li>
                  <li class="b_algo">
                    <h2><a href="https://organic-result.com">Organic Result</a></h2>
                  </li>
                </div>
              </body>
            </html>
          HTML
          mock_page = create_html_mock_page(realistic_html)

          # Act
          links = scraper.send(:extract_links, mock_page, 1)

          # Assert
          expect(links).to be_an(Array)
          expect(links.length).to eq(1)
          expect(links.first[:url]).to eq("https://organic-result.com")
          expect(links.first[:title]).to eq("Organic Result")

          # Cleanup
          scraper.close
        end
      end
    end

    private

    def create_html_mock_page(html_content)
      mock_page_class = Class.new do
        def initialize(html_content)
          @doc = Nokogiri::HTML(html_content)
        end

        def css(selector)
          @doc.css(selector).map { |element| NokoElement.new(element) }
        end

        def at_css(selector)
          element = @doc.at_css(selector)
          element ? NokoElement.new(element) : nil
        end

        def body
          @doc.to_s
        end

        def current_url
          "https://www.bing.com/search?q=api+development"
        end
      end

      mock_page_class.new(html_content)
    end
  end
end
