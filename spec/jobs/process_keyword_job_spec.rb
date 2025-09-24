require 'rails_helper'

RSpec.describe ProcessKeywordJob, type: :job do
  describe '#perform' do
    it 'processes a keyword successfully' do
      user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
      keyword_upload = KeywordUpload.create!(
        user: user,
        original_filename: 'test.csv',
        status: 'queued',
        keyword_count: 1,
        processed_keywords_count: 0
      )
      keyword = Keyword.create!(
        user: user,
        keyword_upload: keyword_upload,
        phrase: 'test keyword',
        status: 'pending'
      )

      scraper_result = double(
        ads_count: 5,
        links_count: 10,
        ads: [{'title' => 'Test Ad', 'url' => 'http://example.com'}],
        links: [{'title' => 'Test Link', 'url' => 'http://example.com'}],
        html: '<html>test</html>'
      )

      scraper_instance = double('scraper')
      allow(Scrapers::BingKeywordScraper).to receive(:new).and_return(scraper_instance)
      allow(scraper_instance).to receive(:call).and_return(scraper_result)
      allow(scraper_instance).to receive(:close)

      ProcessKeywordJob.perform_now(keyword.id)

      keyword.reload
      expect(keyword.status).to eq('completed')
      expect(keyword.ads_count).to eq(5)
      expect(keyword.links_count).to eq(10)
      expect(keyword.scraped_at).to be_present
    end

    it 'handles keyword not found gracefully' do
      expect { ProcessKeywordJob.perform_now(999999) }.not_to raise_error
    end

    it 'handles scraping errors' do
      user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
      keyword_upload = KeywordUpload.create!(
        user: user,
        original_filename: 'test.csv',
        status: 'queued',
        keyword_count: 1,
        processed_keywords_count: 0
      )
      keyword = Keyword.create!(
        user: user,
        keyword_upload: keyword_upload,
        phrase: 'test keyword',
        status: 'pending'
      )

      scraper_instance = double('scraper')
      allow(Scrapers::BingKeywordScraper).to receive(:new).and_return(scraper_instance)
      allow(scraper_instance).to receive(:call).and_raise(StandardError.new('Scraping failed'))
      allow(scraper_instance).to receive(:close)

      ProcessKeywordJob.perform_now(keyword.id)

      keyword.reload
      expect(keyword.status).to eq('failed')
      expect(keyword.error_message).to eq('Scraping failed')
    end

    it 'updates keyword upload processed count' do
      user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
      keyword_upload = KeywordUpload.create!(
        user: user,
        original_filename: 'test.csv',
        status: 'queued',
        keyword_count: 1,
        processed_keywords_count: 0
      )
      keyword = Keyword.create!(
        user: user,
        keyword_upload: keyword_upload,
        phrase: 'test keyword',
        status: 'pending'
      )

      scraper_result = double(
        ads_count: 3,
        links_count: 7,
        ads: [],
        links: [],
        html: '<html>test</html>'
      )

      scraper_instance = double('scraper')
      allow(Scrapers::BingKeywordScraper).to receive(:new).and_return(scraper_instance)
      allow(scraper_instance).to receive(:call).and_return(scraper_result)
      allow(scraper_instance).to receive(:close)

      expect { ProcessKeywordJob.perform_now(keyword.id) }.to change {
        keyword_upload.reload.processed_keywords_count
      }.from(0).to(1)
    end

    it 'handles progress callbacks during scraping' do
      user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
      keyword_upload = KeywordUpload.create!(
        user: user,
        original_filename: 'test.csv',
        status: 'queued',
        keyword_count: 1,
        processed_keywords_count: 0
      )
      keyword = Keyword.create!(
        user: user,
        keyword_upload: keyword_upload,
        phrase: 'test keyword',
        status: 'pending'
      )

      scraper_instance = double('scraper')
      allow(Scrapers::BingKeywordScraper).to receive(:new).and_return(scraper_instance)
      allow(scraper_instance).to receive(:close)

      # Mock scraper to call progress callback
      allow(scraper_instance).to receive(:call) do |phrase, &block|
        if block
          block.call({
            ads: [{'title' => 'Progress Ad'}],
            links: [{'title' => 'Progress Link'}],
            ads_count: 1,
            links_count: 1,
            current_page: 1,
            html: '<html>progress</html>'
          })
        end

        double(
          ads_count: 1,
          links_count: 1,
          ads: [{'title' => 'Final Ad'}],
          links: [{'title' => 'Final Link'}],
          html: '<html>final</html>'
        )
      end

      ProcessKeywordJob.perform_now(keyword.id)

      keyword.reload
      expect(keyword.status).to eq('completed')
      expect(keyword.ads_data).to be_present
      expect(keyword.links_data).to be_present
    end

    it 'processes keyword with HTML content' do
      user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
      keyword_upload = KeywordUpload.create!(
        user: user,
        original_filename: 'test.csv',
        status: 'queued',
        keyword_count: 1,
        processed_keywords_count: 0
      )
      keyword = Keyword.create!(
        user: user,
        keyword_upload: keyword_upload,
        phrase: 'test keyword',
        status: 'pending'
      )

      scraper_result = double(
        ads_count: 1,
        links_count: 2,
        ads: [{'title' => 'Ad'}],
        links: [{'title' => 'Link'}],
        html: '<html><body>Full page HTML</body></html>'
      )

      scraper_instance = double('scraper')
      allow(Scrapers::BingKeywordScraper).to receive(:new).and_return(scraper_instance)
      allow(scraper_instance).to receive(:call).and_return(scraper_result)
      allow(scraper_instance).to receive(:close)

      ProcessKeywordJob.perform_now(keyword.id)

      keyword.reload
      expect(keyword.status).to eq('completed')
      expect(keyword.ads_count).to eq(1)
      expect(keyword.links_count).to eq(2)
    end
  end
end