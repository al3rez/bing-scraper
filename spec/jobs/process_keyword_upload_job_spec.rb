require 'rails_helper'

RSpec.describe ProcessKeywordUploadJob, type: :job do
  describe '#perform' do
    it 'creates and calls KeywordUploadProcessor' do
      user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
      keyword_upload = KeywordUpload.create!(user: user, original_filename: 'test.csv', status: 'queued', keyword_count: 1, processed_keywords_count: 0)

      mock_processor = instance_double(KeywordUploadProcessor)
      allow(KeywordUploadProcessor).to receive(:new).with(upload: keyword_upload).and_return(mock_processor)
      allow(mock_processor).to receive(:call)

      expect(KeywordUploadProcessor).to receive(:new).with(upload: keyword_upload)
      expect(mock_processor).to receive(:call)

      ProcessKeywordUploadJob.perform_now(keyword_upload.id)
    end

    it 'handles missing upload gracefully' do
      expect { ProcessKeywordUploadJob.perform_now(999999) }.not_to raise_error
    end

    context 'when processor raises an error' do
      it 'allows the error to bubble up' do
          user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
        keyword_upload = KeywordUpload.create!(user: user, original_filename: 'test.csv', status: 'queued', keyword_count: 1, processed_keywords_count: 0)

        mock_processor = instance_double(KeywordUploadProcessor)
        allow(KeywordUploadProcessor).to receive(:new).with(upload: keyword_upload).and_return(mock_processor)
        allow(mock_processor).to receive(:call).and_raise(StandardError.new('Processing failed'))

          expect { ProcessKeywordUploadJob.perform_now(keyword_upload.id) }.to raise_error(StandardError, 'Processing failed')
      end
    end

    context 'when processor runs successfully' do
      it 'processes the upload with mocked scraper' do
          user = User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
        keyword_upload = KeywordUpload.create!(user: user, original_filename: 'test.csv', status: 'queued', keyword_count: 1, processed_keywords_count: 0)
        keyword = Keyword.create!(user: user, keyword_upload: keyword_upload, phrase: 'test keyword', status: 'pending')

        mock_scraper = instance_double(Scrapers::BingKeywordScraper)
        mock_result = instance_double(Scrapers::BingKeywordScraper::Result,
          ads_count: 2,
          links_count: 5,
          ads: [{'title' => 'Test Ad'}],
          links: [{'title' => 'Test Link'}],
          html: '<html>test</html>'
        )

        allow(Scrapers::BingKeywordScraper).to receive(:new).and_return(mock_scraper)
        allow(mock_scraper).to receive(:call).and_return(mock_result)
        allow(mock_scraper).to receive(:close)

          ProcessKeywordUploadJob.perform_now(keyword_upload.id)

          keyword_upload.reload
        expect(keyword_upload.status).to eq('completed')
        expect(keyword_upload.processed_keywords_count).to eq(1)

        keyword.reload
        expect(keyword.status).to eq('completed')
        expect(keyword.ads_count).to eq(2)
        expect(keyword.links_count).to eq(5)
      end
    end
  end
end