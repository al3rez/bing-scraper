# Bing Scraper - Web Data Extraction Application

A production-ready web application that extracts and analyzes search result data from Bing at scale. Built with Ruby on Rails 8, featuring real-time processing, comprehensive data extraction, and a modern user interface.

## 🚀 Live Demo

Deployed on Heroku with production-ready architecture.

## 📋 Features

### Core Functionality
- **Bulk Keyword Processing**: Upload CSV files containing 1-100 keywords for automated search processing
- **Real-time Data Extraction**: Extracts comprehensive data from Bing search results including:
  - Total number of Bing Ads advertisers on each page
  - Complete link inventory from search results
  - Full HTML page capture for archival
- **Progressive Updates**: View results as they process in real-time without page refresh
- **User Authentication**: Secure, personalized experience with Devise authentication
- **Responsive Design**: Modern, mobile-friendly interface built with TailwindCSS

### Technical Highlights
- **Background Processing**: Asynchronous job processing with Sidekiq for optimal performance
- **Smart Scraping**: Intelligent workarounds for mass-searching limitations using headless Chrome
- **Memory Optimization**: Streaming CSV parsing and efficient data handling
- **Production Ready**: Architected for scale with proper error handling and monitoring

## 🏗️ Architecture & Development Process

### Development Journey
The development followed a pragmatic, iterative approach:

1. **Proof of Concept**: Started with `scrape.rb` - a standalone script to validate the scraping approach
2. **Service Extraction**: Refactored the working script into a reusable service object pattern
3. **Job Integration**: Connected the service layer with background job processing for scalability
4. **Full Stack Integration**: Built the complete web application around the proven core functionality

### Technology Stack

#### Core Framework
- **Ruby on Rails 8.0**: Chosen for rapid development and proven scalability
- **PostgreSQL**: Robust data storage with ActiveRecord ORM
- **Redis**: High-performance caching and Sidekiq job queue backend

#### Authentication & Background Jobs
- **Devise**: Battle-tested authentication solution
  - While Rails 8 offers built-in authentication, Devise was selected for its maturity and extensive feature set
- **Sidekiq**: Industry-standard background job processor
  - Considered Solid Queue (Rails 8's new offering) but opted for Sidekiq's proven track record

#### Frontend
- **TailwindCSS**: Utility-first CSS framework for rapid UI development
- **Stimulus.js**: Lightweight JavaScript framework for progressive enhancement
- **Note on SASS**: Intentionally disabled as it conflicts with TailwindCSS's JIT compiler

#### Scraping Technology
- **Selenium WebDriver**: Headless browser automation
- **Chrome for Testing**: Consistent, versioned Chrome binaries for reliable scraping

### Code Quality & Conventions

The codebase strictly follows established conventions:
- **Service Objects**: Business logic encapsulation (`app/services/`)
- **Job Objects**: Background processing handlers (`app/jobs/`)
- **Comprehensive Testing**: Full test coverage with RSpec
- **Code Style**: Consistent formatting with RuboCop
- **Documentation**: Clear inline documentation and meaningful commit messages

## 🚢 Deployment (Heroku)

### Infrastructure Setup

The application runs on Heroku with the following configuration:

#### Buildpacks
```bash
1. heroku/ruby
2. heroku-community/chrome-for-testing
```

#### Resources
- **2 Dynos**:
  - Web dyno for application serving
  - Worker dyno for background job processing
- **Heroku Postgres**: Production database
- **Heroku Key-Value Store**: Redis instance for Sidekiq

### Deployment Steps

1. **Create Heroku App**
```bash
heroku create your-app-name
```

2. **Add Buildpacks**
```bash
heroku buildpacks:add heroku/ruby
heroku buildpacks:add heroku-community/chrome-for-testing
```

3. **Provision Add-ons**
```bash
heroku addons:create heroku-postgresql:essential-0
heroku addons:create heroku-redis:mini
```

4. **Configure Environment**
```bash
heroku config:set RAILS_ENV=production
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
```

5. **Deploy**
```bash
git push heroku main
heroku run rails db:migrate
heroku ps:scale worker=1
```

## 🛠️ Local Development

### Prerequisites
- Ruby 3.3.0
- PostgreSQL 14+
- Redis 6+
- Chrome/Chromium browser

### Setup

1. **Clone Repository**
```bash
git clone https://github.com/yourusername/bing-scraper.git
cd bing-scraper
```

2. **Install Dependencies**
```bash
bundle install
yarn install
```

3. **Database Setup**
```bash
rails db:create
rails db:migrate
rails db:seed # Optional: loads sample data
```

4. **Environment Configuration**
```bash
cp .env.example .env
# Edit .env with your configuration
```

5. **Start Services**
```bash
# Terminal 1: Rails server
rails server

# Terminal 2: Sidekiq worker
bundle exec sidekiq

# Terminal 3: TailwindCSS watcher (development)
rails tailwindcss:watch
```

Visit `http://localhost:3000`

## 📊 Usage

1. **Sign Up/Sign In**: Create an account or log in
2. **Upload Keywords**:
   - Click "Upload CSV" or drag & drop your file
   - File validates automatically showing keyword count
   - CSV format: Single column with optional "keyword" header
3. **Monitor Progress**:
   - Real-time updates show processing status
   - View results as each keyword completes
4. **View Results**:
   - Click any keyword to see detailed results
   - Download HTML captures for archival
   - Export data for analysis

## 🧪 Testing

```bash
# Run all tests
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec

# Run specific test file
bundle exec rspec spec/services/keyword_ingestion_service_spec.rb

# Run system tests (requires Chrome)
bundle exec rspec spec/system
```

## 📁 Project Structure

```
app/
├── controllers/       # Request handling
├── models/           # Data models
├── views/            # UI templates
├── services/         # Business logic
│   ├── keyword_ingestion_service.rb
│   ├── keyword_upload_processor.rb
│   └── scrapers/
│       └── bing_keyword_scraper.rb
├── jobs/             # Background jobs
│   └── process_keyword_upload_job.rb
└── javascript/       # Stimulus controllers

spec/
├── models/          # Model tests
├── services/        # Service tests
├── system/          # Integration tests
└── fixtures/        # Test data
```

## 🔧 Configuration

### Key Environment Variables
```bash
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=enabled
```

### Scraping Configuration
- Adjustable delays between searches to avoid rate limiting
- Configurable timeout and retry logic
- User-agent rotation capability

## 📈 Performance Considerations

- **Concurrent Processing**: Multiple keywords processed in parallel via Sidekiq
- **Memory Efficient**: Streaming CSV parsing prevents memory bloat
- **Rate Limiting**: Intelligent delays prevent IP blocking
- **Caching**: Redis caching for frequently accessed data
- **Database Indexing**: Optimized queries with proper indexes

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'add: amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is proprietary and confidential.

## 🙏 Acknowledgments

- Built following established Rails conventions and best practices
- TailwindCSS for the beautiful, responsive UI
- The Ruby on Rails community for excellent documentation and tools

---

**Note**: This application was developed as a technical challenge demonstrating production-ready web scraping at scale. The architecture prioritizes reliability, maintainability, and user experience while working within the constraints of web scraping limitations.