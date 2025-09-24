# app/services/scrapers/bing_keyword_scraper.rb
# frozen_string_literal: true

require "cgi"
require "ferrum"
require "fileutils"
require "uri"

module Scrapers
  class BingKeywordScraper
    Result = Struct.new(:html, :ads, :links, :result_url, keyword_init: true) do
      def ads_count
        ads&.size.to_i
      end

      def links_count
        links&.size.to_i
      end
    end

    USER_AGENT = ENV.fetch("SCRAPER_USER_AGENT", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    BASE_URL = "https://www.bing.com"

    RESULT_SELECTOR = "#b_results > li.b_algo h2 a"
    RESULTS_CONTAINER_SELECTOR = "#b_results"
    AD_CONTAINER_SELECTOR = "li.b_ad"
    PAGINATION_CONTAINER_SELECTOR = "#b_results > li.b_pag"
    PAGE_LINK_SELECTOR = "li.b_pag a[aria-label='Page %{page}']"
    PAGINATION_FALLBACK_SELECTOR = "#b_results > li.b_pag > nav > ul > li:nth-of-type(%{index}) > a"
    NEXT_PAGE_SELECTOR = "li.b_pag a[aria-label='Next page'], li.b_pag a.sb_pagN"

    DEFAULT_TIMEOUT = ENV.fetch("SCRAPER_TIMEOUT_SECONDS", 30).to_i
    DEFAULT_WAIT_TIMEOUT = ENV.fetch("SCRAPER_WAIT_TIMEOUT", DEFAULT_TIMEOUT).to_i
    DEFAULT_WAIT_STEP = ENV.fetch("SCRAPER_WAIT_STEP", 0.2).to_f
    HUMAN_DELAY_MIN = ENV.fetch("SCRAPER_DELAY_MIN_SECONDS", 0.6).to_f
    HUMAN_DELAY_MAX = ENV.fetch("SCRAPER_DELAY_MAX_SECONDS", 1.8).to_f
    MAX_RESULTS_PER_PAGE = 10 # Approximate number of results per Bing page
    MAX_TOTAL_RESULTS = 100 # Maximum results we want to collect per PRD

    CACHE_DIR = Rails.root.join("storage", "page_cache")

    attr_reader :browser

    def initialize(browser: nil, headless: default_headless?)
      @browser = browser || build_browser(headless: headless)
    end

    def call(query, max_results: MAX_TOTAL_RESULTS, &progress_callback)
      page = browser.create_page
      page.headers.set("User-Agent" => USER_AGENT)

      search_url = "#{BASE_URL}/search?q=#{CGI.escape(query)}"
      page.go_to(search_url)
      page.network.wait_for_idle(timeout: DEFAULT_TIMEOUT)
      wait_for(page, RESULTS_CONTAINER_SELECTOR)

      simulate_page_view(page)
      ensure_ads_loaded(page)  # Ensure ads are loaded on first page

      all_links = []
      all_ads = []
      current_page = 1
      max_pages = (max_results.to_f / MAX_RESULTS_PER_PAGE).ceil

      html = nil

      loop do
        begin
          # Ensure ads are loaded before extraction (for subsequent pages)
          ensure_ads_loaded(page) if current_page > 1

          # Extract results from current page
          page_links = extract_links(page, current_page)
          page_ads = extract_ads(page, current_page)

          all_links.concat(page_links)
          all_ads.concat(page_ads)

          # Cache the current page HTML
          html = page.body

          # Call progress callback after each page if provided
          if progress_callback
            progress_callback.call(
              ads: all_ads.dup,
              links: all_links.dup,
              ads_count: all_ads.size,
              links_count: all_links.size,
              current_page: current_page,
              html: html
            )
          end

          # Stop if we have enough results or reached the last page we care about
          break if all_links.size >= max_results || current_page >= max_pages

          # Navigate to the next page; abort loop if navigation fails
          break unless navigate_to_next_page(page, current_page + 1)

          current_page += 1
          simulate_page_view(page)
        rescue Ferrum::Error => e
          puts "[WARNING] Pagination error on page #{current_page}: #{e.message}"
          break
        end
      end

      # Limit results to the requested maximum
      final_links = all_links.take(max_results)
      final_ads = all_ads.take(max_results)

      Result.new(
        html: html,
        ads: final_ads,
        links: final_links,
        result_url: page.current_url
      )
    ensure
      page&.close
      throttle_requests
    end

    def close
      browser.quit
    rescue
      # ignore
    end

    private

    def build_browser(headless:)
      Ferrum::Browser.new(
        headless: headless,
        timeout: DEFAULT_TIMEOUT,
        browser_options: {
          "--disable-gpu" => nil,
          "--disable-dev-shm-usage" => nil,
          "--window-size" => "1280,720",
          "--no-sandbox" => nil,
          "no-sandbox" => nil,
        }
      )
    end

    def default_headless?
      ENV.fetch("SCRAPER_HEADLESS", "true") == "true"
    end

    def wait_for(page, selector)
      elapsed = 0
      until (node = page.at_css(selector))
        raise Ferrum::TimeoutError, "Timed out waiting for #{selector}" if elapsed >= DEFAULT_WAIT_TIMEOUT
        sleep(DEFAULT_WAIT_STEP)
        elapsed += DEFAULT_WAIT_STEP
      end
      node
    end

    def ensure_ads_loaded(page, timeout: 5)
      wait_for(page, AD_CONTAINER_SELECTOR)
      # Give ads a bit more time to fully render
      sleep(0.5)
    rescue Ferrum::TimeoutError => e
      Rails.logger.debug "Ads did not load within #{timeout}s: #{e.message}"
      nil
    end

    def simulate_page_view(page)
      # mimic human scroll + mouse
      begin
        page.mouse.move(x: rand(80..640), y: rand(80..560), steps: rand(2..5))
      rescue
        nil
      end
      human_delay
      begin
        page.mouse.scroll_to(0, rand(200..720))
      rescue
        nil
      end
      human_delay
    end

    def extract_links(page, page_number = 1)
      # Get all organic results - Bing uses li.b_algo for organic results
      # This naturally excludes ads which are in li.b_ad
      page.css("#b_results > li.b_algo h2 a").map do |a|
        href = a.attribute("href").to_s.strip
        next if href.empty?

        # Get title from the link text
        title = a.text.strip

        {
          url: href,
          title: title.present? ? title : "Untitled",
          cite: nil,  # Simplified - cite extraction was causing issues with Ferrum
          page: page_number
        }
      end.compact
    end

    def extract_ads(page, page_number = 1)
      ads = []
      page.css(AD_CONTAINER_SELECTOR).each do |container|
        container.css("li").each do |item|
          # Try multiple selectors for ad links, including the new Bing ad structure
          primary_link = item.at_css("h2.b_topTitleAd a, .mma_smallcard_title a, .smallmma_ad_title a, h2 a, h3 a, .b_title a")
          next unless primary_link

          href = primary_link.attribute("href").to_s.strip
          title = primary_link.text.strip
          next if href.empty? || title.empty?
          next if href.include?("javascript:void") # Skip placeholder links

          ads << {
            title: title,
            url: href,
            page: page_number
          }
        end
      end
      ads
    end

    def navigate_to_next_page(page, target_page)
      # Scroll to bottom to ensure pagination is loaded
      begin
        page.mouse.scroll_to(0, page.evaluate("document.body.scrollHeight"))
        human_delay(min: 0.5, max: 1.0)
      rescue
        nil
      end

      # Wait for pagination container to be present
      wait_for(page, PAGINATION_CONTAINER_SELECTOR)

      # Try to find the specific page link first
      selector = format(PAGE_LINK_SELECTOR, page: target_page)
      link = page.at_css(selector)

      # If specific page link not found, try fallback selector
      if link.nil? || link.attribute("href").to_s.empty?
        fallback_selector = format(PAGINATION_FALLBACK_SELECTOR, index: target_page)
        link = page.at_css(fallback_selector)
      end

      # If still not found, try next page link
      if link.nil? || link.attribute("href").to_s.empty?
        link = page.at_css(NEXT_PAGE_SELECTOR)
      end

      return false unless link && !link.attribute("href").to_s.empty?

      # Click the pagination link
      link.click
      page.network.wait_for_idle(timeout: DEFAULT_TIMEOUT)

      # Wait for results to load on the new page
      wait_for(page, RESULTS_CONTAINER_SELECTOR)
      
      true
    rescue Ferrum::Error => e
      puts "[DEBUG] Failed to navigate to page #{target_page}: #{e.message}"
      false
    end

    def throttle_requests
      human_delay
    end

    def human_delay(min = HUMAN_DELAY_MIN, max = HUMAN_DELAY_MAX)
      span = max - min
      sleep(min + rand * (span.positive? ? span : 0))
    end
  end
end
