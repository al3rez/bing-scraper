require "rails_helper"

RSpec.describe KeywordIngestionService, type: :service do
  describe "#call" do
    context "when given a valid CSV file" do
      it "creates a keyword upload with keywords" do
        user = User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123")
        file_path = Rails.root.join("spec/fixtures/files/keywords.csv")
        original_filename = "test_keywords.csv"
        service = described_class.new(user: user, file_path: file_path, original_filename: original_filename)

        result = service.call

        expect(result).to be_a(KeywordUpload)
        expect(result.user).to eq(user)
        expect(result.original_filename).to eq(original_filename)
        expect(result.status).to eq("queued")
        expect(result.keyword_count).to eq(51)
        expect(result.keywords.count).to eq(51)
      end

      it "creates keywords with correct attributes" do
        user = User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123")
        file_path = Rails.root.join("spec/fixtures/files/keywords.csv")
        original_filename = "test_keywords.csv"
        service = described_class.new(user: user, file_path: file_path, original_filename: original_filename)

        result = service.call
        first_keyword = result.keywords.first

        expect(first_keyword.phrase).to eq("ruby programming")
        expect(first_keyword.user).to eq(user)
        expect(first_keyword.status).to eq("pending")
        expect(first_keyword.ads_count).to eq(0)
        expect(first_keyword.links_count).to eq(0)
      end
    end

    context "when file does not exist" do
      it "raises an error" do
        user = User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123")
        file_path = "/nonexistent/file.csv"
        original_filename = "nonexistent.csv"
        service = described_class.new(user: user, file_path: file_path, original_filename: original_filename)

        expect { service.call }.to raise_error(ArgumentError, /File not found/)
      end
    end

    context "when file is empty" do
      it "raises an argument error" do
        user = User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123")
        empty_file = Tempfile.new([ "empty", ".csv" ])
        empty_file.write("")
        empty_file.rewind

        service = described_class.new(user: user, file_path: empty_file.path, original_filename: "empty.csv")

        expect { service.call }.to raise_error(ArgumentError, /No keywords found/)

        # Cleanup
        empty_file.close!
      end
    end

    context "when file has only whitespace" do
      it "raises an argument error" do
        user = User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123")
        whitespace_file = Tempfile.new([ "whitespace", ".csv" ])
        whitespace_file.write("  \n  \n")
        whitespace_file.rewind

        service = described_class.new(user: user, file_path: whitespace_file.path, original_filename: "whitespace.csv")

        expect { service.call }.to raise_error(ArgumentError, /No keywords found/)

        # Cleanup
        whitespace_file.close!
      end
    end
  end
end
