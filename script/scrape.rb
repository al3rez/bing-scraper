#!/usr/bin/env ruby
# frozen_string_literal: true

require "ferrum"
require "fileutils"
require "uri"

USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.97 Safari/537.36"
RESULT_SELECTOR = "#b_results > li> h2 > a"
PAGINATION_CONTAINER_SELECTOR = "#b_results > li.b_pag"
PAGE_LINK_SELECTOR = "li.b_pag a[aria-label='Page %{page}']"
PAGINATION_FALLBACK_SELECTOR = "#b_results > li.b_pag > nav > ul > li:nth-of-type(%{index}) > a"
NEXT_PAGE_SELECTOR = "li.b_pag a[aria-label='Next page'], li.b_pag a.sb_pagN"
AD_CONTAINER_SELECTOR = "li.b_ad"
DEFAULT_WAIT_TIMEOUT = 10
DEFAULT_WAIT_INTERVAL = 0.2
CACHE_DIR = File.expand_path("storage/page_cache", __dir__)

class Ferrum::Browser
  def wait_for(want, wait: 1, step: 0.1)
    selector = want.to_s
    meth = selector.lstrip.start_with?("/") ? :at_xpath : :at_css
    remaining = wait.to_f
    until (node = send(meth, selector))
      remaining -= step
      return nil if remaining <= 0
      sleep(step)
    end
    node
  end
end

class Ferrum::Page
  def wait_for(want, wait: 1, step: 0.1)
    selector = want.to_s
    meth = selector.lstrip.start_with?("/") ? :at_xpath : :at_css
    remaining = wait.to_f
    until (node = send(meth, selector))
      remaining -= step
      return nil if remaining <= 0
      sleep(step)
    end
    node
  end
end

def human_delay(min: 0.6, max: 1.8)
  span = max - min
  sleep(min + rand * (span.positive? ? span : 0))
rescue Interrupt
  raise
rescue => e
  puts "[DEBUG] human_delay interrupted: #{e.message}"
end

def wait_for_selector(page, selector, timeout: DEFAULT_WAIT_TIMEOUT, interval: DEFAULT_WAIT_INTERVAL)
  page.wait_for(selector, wait: timeout, step: interval)
end

def scroll_to_bottom(page, steps: 3)
  total_height = begin
    page.evaluate("document.body.scrollHeight")
  rescue
    nil
  end
  return unless total_height

  steps = [ steps, 3 ].max
  current_position = begin
    page.evaluate("window.scrollY")
  rescue
    0
  end
  step_size = [ (total_height.to_f / steps).ceil, 200 ].max

  steps.times do |index|
    current_position = [ current_position + step_size + rand(0..120), total_height ].min
    page.evaluate("window.scrollTo(0, #{current_position})")
    page.network.wait_for_idle(timeout: 5)
    human_delay(min: 0.4, max: 1.2)
  rescue Ferrum::Error => e
    puts "[DEBUG] Failed to scroll on attempt #{index + 1}: #{e.message}"
    break
  end
  human_delay(min: 0.6, max: 1.4)
end

def sanitize_cache_key(text)
  sanitized = text.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/^_|_$/, "")
  sanitized.empty? ? "query" : sanitized
end

def simulate_mouse_movements(page, moves: rand(2..4))
  moves.times do
    x = rand(80..720)
    y = rand(120..780)
    page.mouse.move(x: x, y: y, steps: rand(2..5))
    human_delay(min: 0.2, max: 0.6)
  end
rescue Ferrum::Error => e
  puts "[DEBUG] Mouse movement failed: #{e.message}"
end

def simulate_page_view(page)
  human_delay(min: 0.8, max: 1.6)
  simulate_mouse_movements(page)
  scroll_to_bottom(page, steps: rand(4..6))
  human_delay(min: 0.6, max: 1.5)
  page.mouse.scroll_to(0, 0)
  human_delay(min: 0.4, max: 1.0)
rescue Ferrum::Error => e
  puts "[DEBUG] Page simulation failed: #{e.message}"
end

def ensure_ads_loaded(page, timeout: 5)
  wait_for_selector(page, AD_CONTAINER_SELECTOR, timeout: timeout)
rescue Ferrum::Error => e
  puts "[DEBUG] Ads did not load within #{timeout}s: #{e.message}"
  nil
end

def cache_page_html(html, prefix:, page_number:)
  FileUtils.mkdir_p(CACHE_DIR)
  filename = "#{prefix}_page#{page_number}.html"
  path = File.join(CACHE_DIR, filename)
  File.write(path, html, mode: "w", external_encoding: Encoding::UTF_8)
  path
rescue => e
  puts "[DEBUG] Unable to cache page #{page_number}: #{e.message}"
  nil
end

def extract_ads(page)
  ads = []
  page.css(AD_CONTAINER_SELECTOR).each do |container|
    container.css("li").each do |item|
      primary_link = item.at_css(".mma_smallcard_title a, .smallmma_ad_title a, h2 a, h3 a")
      next unless primary_link

      href = primary_link.attribute("href").to_s.strip
      title = primary_link.text.to_s.strip
      next if href.empty? || title.empty?

      display_url = item.at_css("cite")&.text.to_s.strip
      snippet = item.at_css(".mma_smallcard_description, .smallmma_ad_description, p")&.text.to_s.strip
      advertiser = advertiser_name(display_url, href, item)

      ads << {
        title: title,
        url: href,
        display_url: display_url,
        advertiser: advertiser,
        snippet: snippet
      }
    end
  end
  ads
end

def advertiser_name(display_url, href, node)
  caret_href = node.at_css("cite a.b_adcaret")&.attribute("href")
  if caret_href
    match = caret_href.to_s.match(/ads=([^&]+)/)
    if match
      candidate = match[1].split(",").first.to_s.strip
      return candidate unless candidate.empty?
    end
  end

  unless display_url.to_s.strip.empty?
    return display_url.split.first.to_s.strip
  end

  begin
    URI.parse(href).host&.sub(/^www\./, "")
  rescue
    nil
  end
end

def record_ads(page, ads, advertisers, seen_ad_urls)
  extract_ads(page).each do |ad|
    href = ad[:url]
    next if href.to_s.empty? || seen_ad_urls.include?(href)

    seen_ad_urls << href
    ads << ad

    advertiser = ad[:advertiser].to_s.strip
    advertisers << advertiser unless advertiser.empty?
  end
end

def navigate_to_page(page, page_number)
  scroll_to_bottom(page)
  wait_for_selector(page, PAGINATION_CONTAINER_SELECTOR, timeout: 5)

  selector = format(PAGE_LINK_SELECTOR, page: page_number)
  link = wait_for_selector(page, selector, timeout: 5)

  if link.nil? || link.attribute("href").to_s.empty?
    fallback_selector = format(PAGINATION_FALLBACK_SELECTOR, index: page_number)
    puts "[DEBUG] #{selector} missing or inert, trying #{fallback_selector}."
    link = wait_for_selector(page, fallback_selector, timeout: 5)

    if link.nil? || link.attribute("href").to_s.empty?
      puts "[DEBUG] Fallback selector did not yield a clickable link, trying #{NEXT_PAGE_SELECTOR}."
      link = wait_for_selector(page, NEXT_PAGE_SELECTOR, timeout: 5)
    end
  end

  raise Ferrum::Error, "Pagination link missing for page #{page_number}" unless link

  link.click
  page.network.wait_for_idle(timeout: 10)

  unless wait_for_selector(page, RESULT_SELECTOR)
    raise Ferrum::Error, "Results selector missing"
  end
end

args = ARGV

if args.empty?
  puts "ruby scrape.rb <max_page> <output> <dork>"
  exit(1)
end

max_page_str = args[0]
output_path = args[1]
query_parts = args[2..]

if max_page_str.nil? || max_page_str.empty?
  puts "Invalid max page."
  exit(1)
end

max_page = begin
  Integer(max_page_str, 10)
rescue ArgumentError
  nil
end

unless max_page
  puts "Max page is not a number."
  exit(1)
end

if output_path.nil? || output_path.empty?
  puts "Invalid output."
  exit(1)
end

if query_parts.nil? || query_parts.empty?
  puts "Invalid dork."
  exit(1)
end

query = query_parts.join
puts "[INFO] Dorking has started."

links = []
info_printed = false
ads = []
advertisers = Set.new
seen_ad_urls = Set.new
seen_links = Set.new
cache_prefix = sanitize_cache_key(query)

extract_links = lambda do |page|
  collected = []
  page.css(RESULT_SELECTOR).each do |node|
    href = node.attribute("href").to_s.strip
    next if href.empty? || seen_links.include?(href)

    seen_links << href
    collected << href
  end
  collected
end

browser = nil

begin
  browser = Ferrum::Browser.new(
    headless: ENV.fetch("BING_HEADLESS", "true") != "false",
    browser_options: {
      "no-sandbox": nil,
      "disable-setuid-sandbox": nil,
      "disable-gpu": nil
    }
  )
  page = browser.create_page
  page.headers.set("User-Agent" => USER_AGENT)

  encoded_query = URI.encode_www_form_component(query)
  page.go_to("https://www.bing.com/search?q=#{encoded_query}")
  page.network.wait_for_idle(timeout: 10)

  html = page.body
  if html.include?("There are no results for")
    puts "[WARNING] Something went wrong while gathering some links, please try again later."
    puts "[INFO] Aborting.."
    exit(1)
  end

  unless wait_for_selector(page, RESULT_SELECTOR)
    puts "[WARNING] Something went wrong while gathering some links, please try again later."
    puts "[INFO] Aborting.."
    exit(1)
  end

  simulate_page_view(page)
  ensure_ads_loaded(page)

  links.concat(extract_links.call(page))
  record_ads(page, ads, advertisers, seen_ad_urls)
  cache_page_html(html, prefix: cache_prefix, page_number: 1)

  if max_page <= 1
    puts "[INFO] #{links.length} links has been gathered."
    info_printed = true
  end

  page_index = 2
  while page_index <= max_page
    human_delay(min: 1.0, max: 2.2)
    begin
      navigate_to_page(page, page_index)
    rescue Ferrum::Error
      puts "[WARNING] Max page detected, aborting links gatherer."
      puts "[INFO] #{links.length} links has been gathered."
      info_printed = true
      break
    end

    simulate_page_view(page)
    ensure_ads_loaded(page)

    html = page.body
    links.concat(extract_links.call(page))
    record_ads(page, ads, advertisers, seen_ad_urls)
    cache_page_html(html, prefix: cache_prefix, page_number: page_index)

    if page_index == max_page
      puts "[INFO] #{links.length} links has been gathered."
      info_printed = true
      break
    end

    page_index += 1
  end
ensure
  browser&.quit
end

puts "[INFO] #{links.length} links has been gathered." unless info_printed
if ads.any?
  puts "[INFO] #{ads.length} ads detected."
  ads.each_with_index do |ad, index|
    label = ad[:advertiser].to_s.strip
    label = ad[:display_url] if label.empty?
    label = ad[:url] if label.to_s.strip.empty?
    puts "[AD #{index + 1}] #{label} - #{ad[:title]}"
  end

  if advertisers.any?
    puts "[INFO] Advertisers: #{advertisers.to_a.sort.join(", ")}"
  end
else
  puts "[INFO] No ads detected."
end
File.write(output_path, links.join("\n"), mode: "w", external_encoding: Encoding::UTF_8)
puts "Finished."
