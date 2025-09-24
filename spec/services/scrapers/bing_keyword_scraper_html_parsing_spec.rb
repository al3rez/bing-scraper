require 'rails_helper'
require 'nokogiri'

RSpec.describe Scrapers::BingKeywordScraper, '#extract_ads and #extract_links', type: :service do
  let(:scraper) { described_class.new(headless: true) }

  # Create a mock page object that uses Nokogiri for HTML parsing
  let(:mock_page_with_html) do
    Class.new do
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
        'https://www.bing.com/search?q=api+development'
      end
    end
  end

  # Wrapper for Nokogiri elements to match Ferrum's API
  let(:noko_element_class) do
    Class.new do
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
  end

  let(:attribute_wrapper_class) do
    Class.new do
      def initialize(value)
        @value = value
      end

      def to_s
        @value.to_s
      end
    end
  end

  before do
    stub_const('NokoElement', noko_element_class)
    stub_const('AttributeWrapper', attribute_wrapper_class)
  end

  describe 'when parsing HTML with ads' do
    let(:ads_html) { File.read(Rails.root.join('spec/fixtures/files/with-ads.html')) }
    let(:mock_page) { mock_page_with_html.new(ads_html) }

    it 'extracts ads from real HTML' do
      ads = scraper.send(:extract_ads, mock_page, 1)

      expect(ads).to be_an(Array)
      expect(ads.length).to be > 0

      first_ad = ads.first
      expect(first_ad).to have_key(:title)
      expect(first_ad).to have_key(:url)
      expect(first_ad).to have_key(:page)
      expect(first_ad[:page]).to eq(1)
      expect(first_ad[:title]).to be_a(String)
      expect(first_ad[:url]).to start_with('http')
    end

    it 'extracts organic links from real HTML' do
      links = scraper.send(:extract_links, mock_page, 1)

      expect(links).to be_an(Array)
      expect(links.length).to be > 0

      first_link = links.first
      expect(first_link).to have_key(:title)
      expect(first_link).to have_key(:url)
      expect(first_link).to have_key(:page)
      expect(first_link[:page]).to eq(1)
      expect(first_link[:title]).to be_a(String)
      expect(first_link[:url]).to start_with('http')
    end
  end

  describe 'when parsing HTML without ads' do
    let(:no_ads_html) { File.read(Rails.root.join('spec/fixtures/files/without-ads.html')) }
    let(:mock_page) { mock_page_with_html.new(no_ads_html) }

    it 'extracts no ads from HTML without ads' do
      ads = scraper.send(:extract_ads, mock_page, 1)

      expect(ads).to be_an(Array)
      expect(ads).to be_empty
    end

    it 'still extracts organic links from HTML without ads' do
      links = scraper.send(:extract_links, mock_page, 1)

      expect(links).to be_an(Array)
      expect(links.length).to be > 0

      first_link = links.first
      expect(first_link).to have_key(:title)
      expect(first_link).to have_key(:url)
      expect(first_link).to have_key(:page)
      expect(first_link[:page]).to eq(1)
    end
  end

  describe 'edge cases' do
    context 'when HTML has ads with various invalid links' do
      let(:realistic_html) do
        <<~HTML
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
      end
      let(:mock_page) { mock_page_with_html.new(realistic_html) }

      it 'filters out invalid ads' do
        ads = scraper.send(:extract_ads, mock_page, 1)

        expect(ads).to be_an(Array)
        expect(ads.length).to eq(1)
        expect(ads.first[:url]).to eq('https://good-ad.com')
        expect(ads.first[:title]).to eq('Good Ad')
      end

      it 'extracts organic links normally' do
        links = scraper.send(:extract_links, mock_page, 1)

        expect(links).to be_an(Array)
        expect(links.length).to eq(1)
        expect(links.first[:url]).to eq('https://organic-result.com')
        expect(links.first[:title]).to eq('Organic Result')
      end
    end
  end

  after do
    scraper.close
  end
end