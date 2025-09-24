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
    raw_lines = CSV.read(file_path, headers: false).flatten
    raw_lines.filter_map { |value| sanitize(value) }.uniq.first(MAX_KEYWORDS)
  rescue Errno::ENOENT
    raise ArgumentError, "File not found: #{file_path}"
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
