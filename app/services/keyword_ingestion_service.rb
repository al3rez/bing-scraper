# frozen_string_literal: true

require "csv"

class KeywordIngestionService
  MAX_KEYWORDS = 100
  MIN_KEYWORDS = 1

  def initialize(user:, file_path:, original_filename: nil)
    @user = user
    @file_path = file_path
    @original_filename = original_filename || File.basename(file_path)
  end

  def call
    phrases = extract_phrases
    validate_phrases!(phrases)

    ActiveRecord::Base.transaction do
      upload = build_upload(phrases)
      persist_keywords(upload, phrases)
      upload
    end
  end

  private

  attr_reader :user, :file_path, :original_filename

  def extract_phrases
    phrases = []
    line_count = 0

    # Stream CSV parsing to avoid loading entire file into memory
    # Use CSV.header_row? to detect headers automatically
    CSV.foreach(file_path, headers: :first_row) do |row|
      # Skip if this is a header row
      next if row.header_row?

      line_count += 1

      # Stop processing if we hit our limit to prevent memory issues
      break if line_count > MAX_KEYWORDS + 10 # Small buffer for duplicates

      # Extract and sanitize phrases from the row
      row_phrases = row.fields.filter_map { |value| sanitize(value) }

      # Only add non-empty phrases to avoid counting blank rows
      phrases.concat(row_phrases) if row_phrases.any?

      # Break early if we have enough unique phrases
      break if phrases.uniq.size >= MAX_KEYWORDS
    end

    phrases.uniq.first(MAX_KEYWORDS)
  rescue Errno::ENOENT
    raise ArgumentError, "File not found: #{file_path}"
  rescue CSV::MalformedCSVError => e
    raise ArgumentError, "Invalid CSV format: #{e.message}"
  end

  def sanitize(value)
    value.to_s.strip.presence
  end

  def validate_phrases!(phrases)
    raise ArgumentError, "No keywords found in #{file_path}" if phrases.empty?
    return if phrases.size.between?(MIN_KEYWORDS, MAX_KEYWORDS)

    raise ArgumentError, "Keyword count must be between #{MIN_KEYWORDS} and #{MAX_KEYWORDS}"
  end

  def build_upload(phrases)
    user.keyword_uploads.create!(
      original_filename: original_filename,
      keyword_count: phrases.size,
      processed_keywords_count: 0,
      status: :queued
    )
  end

  def persist_keywords(upload, phrases)
    phrases.each do |phrase|
      upload.keywords.create!(
        user: user,
        phrase: phrase,
        status: :pending,
        ads_count: 0,
        links_count: 0
      )
    end
  end
end
