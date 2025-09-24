# README

This README would normally document whatever steps are necessary to get the
application up and running.

## Configuration

Set scraping timeouts in `.env` to match the stability of your Bing session:

```bash
# Seconds before Ferrum considers a page load or selector wait a timeout
SCRAPER_TIMEOUT_SECONDS=45

# Optional fine-tuning for selector polling; falls back to SCRAPER_TIMEOUT_SECONDS
SCRAPER_WAIT_TIMEOUT=45
```

If Bing routinely responds slower in your environment, raise these values to avoid
`Ferrum::TimeoutError` inside `ProcessKeywordUploadJob`.
