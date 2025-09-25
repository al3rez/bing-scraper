class KeywordPresenter
  attr_reader :keyword

  def initialize(keyword)
    @keyword = keyword
  end

  def status_text
    case keyword.status
    when "pending"
      "Queued"
    when "processing"
      "Scraping..."
    when "completed"
      if keyword.scraped_at
        "Scraped #{ActionController::Base.helpers.time_ago_in_words(keyword.scraped_at)} ago"
      else
        "Completed"
      end
    when "failed"
      "Failed"
    else
      keyword.status.humanize
    end
  end

  def status_class
    case keyword.status
    when "pending"
      "text-xs text-slate-600"
    when "processing"
      "text-xs text-yellow-600"
    when "completed"
      "text-xs text-green-600"
    when "failed"
      "text-xs text-red-600"
    else
      "text-xs text-slate-600"
    end
  end
end
