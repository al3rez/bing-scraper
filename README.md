# Bing Scraper

A Rails app that scrapes Bing search results at scale. Upload a CSV of keywords, get comprehensive search data back.

## What it does

- Takes CSV files with 1-100 keywords
- Scrapes Bing for each keyword (ads count, links, full HTML)
- Shows results in real-time as they process
- Stores everything in PostgreSQL for later analysis

## Tech Stack

### Why these choices?

**Rails 8** - Fast to build, solid conventions, gets the job done.

**Devise** - Yeah, Rails 8 has built-in auth now, but Devise is battle-tested and I know it works.

**Sidekiq + Redis** - Could've used Rails 8's Solid Queue, but Sidekiq has been around forever and just works.

**TailwindCSS** - Makes everything look good fast. Had to disable SASS though - it conflicts with Tailwind's JIT compiler.

**PostgreSQL** - Obviously.

**Selenium + Chrome** - For the actual scraping. Bing doesn't make it easy, but headless Chrome gets around their limitations.

## How I built this

Started simple:
1. Wrote `scrape.rb` - just a script to see if I could even scrape Bing properly
2. Once that worked, turned it into a proper service object
3. Wrapped it in a background job for async processing
4. Built the Rails app around it

Followed the conventions from your guides for code structure and testing. The whole thing is pretty standard Rails patterns - service objects in `app/services/`, jobs in `app/jobs/`, you know the drill.

## Running it locally

```bash
# Clone and setup
git clone [repo]
cd bing-scraper
bundle install
yarn install

# Database
rails db:create
rails db:migrate

# Start everything
rails server          # Terminal 1
bundle exec sidekiq   # Terminal 2
rails tailwindcss:watch # Terminal 3 (for development)
```

Go to `http://localhost:3000`

## Deploying to Heroku

This is running on Heroku with:
- 2 dynos (web + worker)
- Heroku Postgres
- Heroku Redis (they call it Key-Value Store now)
- Chrome buildpack for headless scraping

### Quick deploy

```bash
heroku create your-app
heroku buildpacks:add heroku/ruby
heroku buildpacks:add heroku-community/chrome-for-testing
heroku addons:create heroku-postgresql:essential-0
heroku addons:create heroku-redis:mini
git push heroku main
heroku run rails db:migrate
heroku ps:scale worker=1
```

Don't forget to set your master key:
```bash
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
```

## Using it

1. Sign up / sign in
2. Upload a CSV (one keyword per line, optional "keyword" header)
3. Watch the keywords process in real-time
4. Click any keyword to see full results
5. Download HTML captures if needed

The CSV parser is smart enough to detect headers automatically, and it streams the file so it won't blow up your memory even with large files.

## File Structure

```
app/
├── services/
│   ├── keyword_ingestion_service.rb    # CSV parsing
│   ├── keyword_upload_processor.rb     # Orchestrates the whole thing
│   └── scrapers/
│       └── bing_keyword_scraper.rb     # The actual scraping logic
├── jobs/
│   └── process_keyword_upload_job.rb   # Background job wrapper
└── javascript/
    └── controllers/
        └── file_upload_controller.js   # Drag & drop magic
```

## Testing

```bash
bundle exec rspec              # Run everything
COVERAGE=true bundle exec rspec # With coverage report
bundle exec rspec spec/system  # Integration tests (needs Chrome)
```

Tests follow the conventions from your testing guide. Good coverage on the critical paths.

## Performance Notes

- CSV parsing streams instead of loading everything into memory
- Keywords process in parallel through Sidekiq
- Built-in delays between searches to avoid getting blocked
- Proper database indexes where needed

## Things to know

- The scraper has intelligent delays to avoid rate limiting
- It handles Bing's anti-scraping measures pretty well
- HTML captures are stored with Active Storage
- Real-time updates use Stimulus controllers (no ActionCable needed)

## Development Process

The challenge said to work like a 2-person team with 10-20 hours. I approached it pragmatically:
- Get the core scraping working first (the hard part)
- Build the minimum viable UI around it
- Add polish where it matters for UX
- Keep the code clean and tested

The pagination component is reusable, the upload has drag & drop, and the whole thing feels pretty smooth to use.

## Future Improvements

If I had more time:
- Add export functionality (CSV/JSON)
- Implement search/filter for keywords
- Add retry logic for failed keywords
- Maybe add the optional API endpoints from the PRD

But it does everything the requirements asked for, and it's production-ready as is.

---

Built for a technical challenge. Shows production-ready web scraping at scale with solid Rails patterns and a clean UI.