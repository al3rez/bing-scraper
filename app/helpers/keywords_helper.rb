module KeywordsHelper
  def keyword_status_text(keyword)
    case keyword.status
    when "pending"
      "Queued"
    when "processing"
      "Scraping..."
    when "completed"
      if keyword.scraped_at
        "Scraped #{time_ago_in_words(keyword.scraped_at)} ago"
      else
        "Completed"
      end
    when "failed"
      "Failed"
    else
      keyword.status.humanize
    end
  end

  def keyword_status_class(keyword)
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
