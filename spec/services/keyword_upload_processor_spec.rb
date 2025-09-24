require 'rails_helper'

RSpec.describe KeywordUploadProcessor, type: :service do
  describe '#call' do
    context 'when processing keywords successfully' do
      it 'processes all keywords and updates upload status' do
        user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
        keyword_upload = KeywordUpload.create!(
          user: user,
          original_filename: 'test.csv',
          status: 'queued',
          keyword_count: 2,
          processed_keywords_count: 0
        )
        keyword1 = Keyword.create!(
          user: user,
          keyword_upload: keyword_upload,
          phrase: 'ruby programming',
          status: 'pending'
        )
        keyword2 = Keyword.create!(
          user: user,
          keyword_upload: keyword_upload,
          phrase: 'python programming',
          status: 'pending'
        )

        mock_scraper = instance_double(Scrapers::BingKeywordScraper)
        mock_result = instance_double(
          Scrapers::BingKeywordScraper::Result,
          ads_count: 3,
          links_count: 10,
          ads: [{'title' => 'Test Ad', 'url' => 'http://ad.example.com'}],
          links: [{'title' => 'Test Link', 'url' => 'http://example.com'}],
          html: '<html>test html</html>'
        )

        allow(mock_scraper).to receive(:call).and_return(mock_result)
        allow(mock_scraper).to receive(:close)

        processor = described_class.new(upload: keyword_upload, scraper: mock_scraper)

        processor.call

        keyword_upload.reload
        expect(keyword_upload.status).to eq('completed')
        expect(keyword_upload.processed_keywords_count).to eq(2)
        expect(keyword_upload.processed_at).to be_present

        keyword1.reload
        expect(keyword1.status).to eq('completed')
        expect(keyword1.ads_count).to eq(3)
        expect(keyword1.links_count).to eq(10)
        expect(keyword1.scraped_at).to be_present

        keyword2.reload
        expect(keyword2.status).to eq('completed')
      end
    end

    context 'when scraper raises an error for a keyword' do
      it 'marks the failed keyword as failed but continues processing' do
        user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
        keyword_upload = KeywordUpload.create!(
          user: user,
          original_filename: 'test.csv',
          status: 'queued',
          keyword_count: 2,
          processed_keywords_count: 0
        )
        keyword1 = Keyword.create!(
          user: user,
          keyword_upload: keyword_upload,
          phrase: 'ruby programming',
          status: 'pending'
        )
        keyword2 = Keyword.create!(
          user: user,
          keyword_upload: keyword_upload,
          phrase: 'python programming',
          status: 'pending'
        )

        mock_scraper = instance_double(Scrapers::BingKeywordScraper)
        mock_result = instance_double(
          Scrapers::BingKeywordScraper::Result,
          ads_count: 2,
          links_count: 5,
          ads: [],
          links: [],
          html: '<html>test</html>'
        )

        allow(mock_scraper).to receive(:call).with('ruby programming').and_raise(StandardError.new('Scraping failed'))
        allow(mock_scraper).to receive(:call).with('python programming').and_return(mock_result)
        allow(mock_scraper).to receive(:close)

        processor = described_class.new(upload: keyword_upload, scraper: mock_scraper)

        processor.call

        keyword1.reload
        expect(keyword1.status).to eq('failed')
        expect(keyword1.error_message).to eq('Scraping failed')

        keyword2.reload
        expect(keyword2.status).to eq('completed')

        keyword_upload.reload
        expect(keyword_upload.status).to eq('completed')
        expect(keyword_upload.processed_keywords_count).to eq(2)
      end
    end

    context 'when upload processing fails completely' do
      it 'marks upload as failed' do
        user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
        keyword_upload = KeywordUpload.create!(
          user: user,
          original_filename: 'test.csv',
          status: 'queued',
          keyword_count: 1,
          processed_keywords_count: 0
        )

        mock_scraper = instance_double(Scrapers::BingKeywordScraper)
        allow(mock_scraper).to receive(:close)
        allow(keyword_upload).to receive(:keywords).and_raise(StandardError.new('Database error'))

        processor = described_class.new(upload: keyword_upload, scraper: mock_scraper)

        expect { processor.call }.to raise_error(StandardError, 'Database error')

        keyword_upload.reload
        expect(keyword_upload.status).to eq('failed')
        expect(keyword_upload.error_message).to eq('Database error')
        expect(keyword_upload.processed_at).to be_present
      end
    end
  end
end