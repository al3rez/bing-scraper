module ScraperHelper
  def create_mock_browser_with_mocks
    mock_browser = instance_double(Ferrum::Browser)
    mock_page = instance_double(Ferrum::Page)
    mock_headers = instance_double(Ferrum::Headers)
    mock_network = instance_double(Ferrum::Network)
    mock_mouse = instance_double(Ferrum::Mouse)

    # Browser mocks
    allow(mock_browser).to receive(:create_page).and_return(mock_page)
    allow(mock_browser).to receive(:quit)

    # Page mocks
    allow(mock_page).to receive(:headers).and_return(mock_headers)
    allow(mock_page).to receive(:network).and_return(mock_network)
    allow(mock_page).to receive(:mouse).and_return(mock_mouse)
    allow(mock_page).to receive(:close)
    allow(mock_page).to receive(:current_url).and_return("https://www.bing.com/search?q=test")
    allow(mock_page).to receive(:go_to)
    allow(mock_page).to receive(:body).and_return("<html>test page</html>")
    allow(mock_page).to receive(:evaluate).and_return(1000)

    # Element finding mocks
    allow(mock_page).to receive(:at_css).with("#b_results").and_return(double("results_container"))
    allow(mock_page).to receive(:at_css).with("li.b_ad").and_return(double("ad_container"))

    # Headers, network, and mouse mocks
    allow(mock_headers).to receive(:set)
    allow(mock_network).to receive(:wait_for_idle)
    allow(mock_mouse).to receive(:move)
    allow(mock_mouse).to receive(:scroll_to)

    [ mock_browser, mock_page ]
  end

  def stub_scraper_delays(scraper_instance)
    # Stub the delay methods to return immediately
    allow(scraper_instance).to receive(:human_delay)
    allow(scraper_instance).to receive(:throttle_requests)
    allow(scraper_instance).to receive(:simulate_page_view)

    # Stub sleep calls
    allow(scraper_instance).to receive(:sleep)
  end
end
