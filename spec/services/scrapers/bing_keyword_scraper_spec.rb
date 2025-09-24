require 'rails_helper'

RSpec.describe Scrapers::BingKeywordScraper, type: :service do
  describe '#call' do
    context 'when page has results' do
      it 'extracts both ads and organic results' do
          mock_browser = instance_double(Ferrum::Browser)
        mock_page = instance_double(Ferrum::Page)
        mock_headers = instance_double(Ferrum::Headers)
        mock_network = instance_double(Ferrum::Network)
        mock_mouse = instance_double(Ferrum::Mouse)

        allow(mock_browser).to receive(:create_page).and_return(mock_page)
        allow(mock_browser).to receive(:quit)
        allow(mock_page).to receive(:headers).and_return(mock_headers)
        allow(mock_page).to receive(:network).and_return(mock_network)
        allow(mock_page).to receive(:mouse).and_return(mock_mouse)
        allow(mock_page).to receive(:close)
        allow(mock_headers).to receive(:set)
        allow(mock_network).to receive(:wait_for_idle)
        allow(mock_mouse).to receive(:move)
        allow(mock_mouse).to receive(:scroll_to)
        allow(mock_page).to receive(:current_url).and_return('https://www.bing.com/search?q=test')
        allow(mock_page).to receive(:go_to)
        allow(mock_page).to receive(:at_css).with('#b_results').and_return(double('results_container'))
        allow(mock_page).to receive(:at_css).with('li.b_ad').and_return(double('ad_container'))
        allow(mock_page).to receive(:body).and_return('<html>test page</html>')
        allow(mock_page).to receive(:evaluate).and_return(1000)

        # Mock organic results
        allow(mock_page).to receive(:css).with('#b_results > li.b_algo h2 a').and_return([
          double('link',
            attribute: double(to_s: 'https://example.com'),
            text: 'Example Result',
            parent: nil
          )
        ])

        # Mock ads
        ad_item = double('ad_item')
        allow(ad_item).to receive(:at_css).with('h2.b_topTitleAd a, .mma_smallcard_title a, .smallmma_ad_title a, h2 a, h3 a, .b_title a').and_return(
          double('ad_link',
            attribute: double(to_s: 'https://ad.example.com'),
            text: 'Test Ad'
          )
        )
        ad_container = double('ad_container')
        allow(ad_container).to receive(:css).with('li').and_return([ad_item])
        allow(mock_page).to receive(:css).with('li.b_ad').and_return([ad_container])

        scraper = described_class.new(browser: mock_browser)

          result = scraper.call('ruby programming', max_results: 10)

          expect(result).to be_a(Scrapers::BingKeywordScraper::Result)
        expect(result.html).to be_present
        expect(result.result_url).to eq('https://www.bing.com/search?q=test')
        expect(result.ads).to be_an(Array)
        expect(result.links).to be_an(Array)
      end

      it 'calls progress callback if provided' do
          mock_browser = instance_double(Ferrum::Browser)
        mock_page = instance_double(Ferrum::Page)
        mock_headers = instance_double(Ferrum::Headers)
        mock_network = instance_double(Ferrum::Network)
        mock_mouse = instance_double(Ferrum::Mouse)

        allow(mock_browser).to receive(:create_page).and_return(mock_page)
        allow(mock_browser).to receive(:quit)
        allow(mock_page).to receive(:headers).and_return(mock_headers)
        allow(mock_page).to receive(:network).and_return(mock_network)
        allow(mock_page).to receive(:mouse).and_return(mock_mouse)
        allow(mock_page).to receive(:close)
        allow(mock_headers).to receive(:set)
        allow(mock_network).to receive(:wait_for_idle)
        allow(mock_mouse).to receive(:move)
        allow(mock_mouse).to receive(:scroll_to)
        allow(mock_page).to receive(:current_url).and_return('https://www.bing.com/search?q=test')
        allow(mock_page).to receive(:go_to)
        allow(mock_page).to receive(:at_css).with('#b_results').and_return(double('results_container'))
        allow(mock_page).to receive(:at_css).with('li.b_ad').and_return(double('ad_container'))
        allow(mock_page).to receive(:body).and_return('<html>test page</html>')
        allow(mock_page).to receive(:evaluate).and_return(1000)

        allow(mock_page).to receive(:css).with('#b_results > li.b_algo h2 a').and_return([
          double('link',
            attribute: double(to_s: 'https://example.com'),
            text: 'Example Result',
            parent: nil
          )
        ])

        ad_item = double('ad_item')
        allow(ad_item).to receive(:at_css).and_return(
          double('ad_link',
            attribute: double(to_s: 'https://ad.example.com'),
            text: 'Test Ad'
          )
        )
        ad_container = double('ad_container')
        allow(ad_container).to receive(:css).with('li').and_return([ad_item])
        allow(mock_page).to receive(:css).with('li.b_ad').and_return([ad_container])

        scraper = described_class.new(browser: mock_browser)
        progress_calls = []

          scraper.call('ruby programming', max_results: 10) do |progress_data|
          progress_calls << progress_data
        end

          expect(progress_calls).not_to be_empty
        expect(progress_calls.first).to have_key(:ads)
        expect(progress_calls.first).to have_key(:links)
        expect(progress_calls.first).to have_key(:current_page)
        expect(progress_calls.first).to have_key(:html)
      end
    end

    context 'when page has no ads' do
      it 'handles missing ads gracefully' do
          mock_browser = instance_double(Ferrum::Browser)
        mock_page = instance_double(Ferrum::Page)
        mock_headers = instance_double(Ferrum::Headers)
        mock_network = instance_double(Ferrum::Network)
        mock_mouse = instance_double(Ferrum::Mouse)

        allow(mock_browser).to receive(:create_page).and_return(mock_page)
        allow(mock_browser).to receive(:quit)
        allow(mock_page).to receive(:headers).and_return(mock_headers)
        allow(mock_page).to receive(:network).and_return(mock_network)
        allow(mock_page).to receive(:mouse).and_return(mock_mouse)
        allow(mock_page).to receive(:close)
        allow(mock_headers).to receive(:set)
        allow(mock_network).to receive(:wait_for_idle)
        allow(mock_mouse).to receive(:move)
        allow(mock_mouse).to receive(:scroll_to)
        allow(mock_page).to receive(:current_url).and_return('https://www.bing.com/search?q=test')
        allow(mock_page).to receive(:go_to)
        allow(mock_page).to receive(:at_css).with('#b_results').and_return(double('results_container'))
        allow(mock_page).to receive(:at_css).with('li.b_ad').and_raise(Ferrum::TimeoutError.new('Ads not found'))
        allow(mock_page).to receive(:body).and_return('<html>test page</html>')
        allow(mock_page).to receive(:evaluate).and_return(1000)
        allow(mock_page).to receive(:css).with('#b_results > li.b_algo h2 a').and_return([
          double('link',
            attribute: double(to_s: 'https://example.com'),
            text: 'Example Result',
            parent: nil
          )
        ])
        allow(mock_page).to receive(:css).with('li.b_ad').and_return([])

        scraper = described_class.new(browser: mock_browser)

          result = scraper.call('ruby programming', max_results: 10)

          expect(result).to be_a(Scrapers::BingKeywordScraper::Result)
        expect(result.ads).to eq([])
        expect(result.links).to be_an(Array)
      end
    end

    context 'when scraping fails' do
      it 'raises the error' do
          mock_browser = instance_double(Ferrum::Browser)
        mock_page = instance_double(Ferrum::Page)

        allow(mock_browser).to receive(:create_page).and_return(mock_page)
        allow(mock_browser).to receive(:quit)
        allow(mock_page).to receive(:headers).and_return(instance_double(Ferrum::Headers, set: nil))
        allow(mock_page).to receive(:network).and_return(instance_double(Ferrum::Network, wait_for_idle: nil))
        allow(mock_page).to receive(:close)
        allow(mock_page).to receive(:go_to).and_raise(Ferrum::Error.new('Connection failed'))

        scraper = described_class.new(browser: mock_browser)

          expect { scraper.call('ruby programming') }.to raise_error(Ferrum::Error, 'Connection failed')
      end
    end
  end

  describe '#close' do
    it 'quits the browser' do
      mock_browser = instance_double(Ferrum::Browser)
      allow(mock_browser).to receive(:quit)
      scraper = described_class.new(browser: mock_browser)

      scraper.close

      expect(mock_browser).to have_received(:quit)
    end

    it 'handles browser quit errors gracefully' do
      mock_browser = instance_double(Ferrum::Browser)
      allow(mock_browser).to receive(:quit).and_raise(StandardError.new('Quit failed'))
      scraper = described_class.new(browser: mock_browser)

      expect { scraper.close }.not_to raise_error
    end
  end

  describe 'Result struct' do
    it 'calculates ads count correctly' do
      result = Scrapers::BingKeywordScraper::Result.new(
        html: '<html>test</html>',
        ads: [{'title' => 'Ad 1'}, {'title' => 'Ad 2'}],
        links: [{'title' => 'Link 1'}],
        result_url: 'https://example.com'
      )

      expect(result.ads_count).to eq(2)
    end

    it 'calculates links count correctly' do
      result = Scrapers::BingKeywordScraper::Result.new(
        html: '<html>test</html>',
        ads: [{'title' => 'Ad 1'}],
        links: [{'title' => 'Link 1'}, {'title' => 'Link 2'}, {'title' => 'Link 3'}],
        result_url: 'https://example.com'
      )

      expect(result.links_count).to eq(3)
    end

    it 'handles nil ads and links' do
      result = Scrapers::BingKeywordScraper::Result.new(ads: nil, links: nil)

      expect(result.ads_count).to eq(0)
      expect(result.links_count).to eq(0)
    end
  end
end