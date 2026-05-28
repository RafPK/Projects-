# 🎮 Game Recommendation System

A content-based game recommendation engine built in R — scraping live data from the RAWG Video Games Database API, engineering rich features, and serving personalized recommendations through an interactive Shiny dashboard.

**[🚀 Live App](https://rafpk.shinyapps.io/game_recommendation_system/)**

---

## Overview

This project tackles a real product problem: given a game a user enjoys, recommend similar titles from a catalogue of 400+ games using content-based filtering. The system combines API-scraped metadata, custom feature engineering, and TF-IDF cosine similarity to generate ranked recommendations — all served through a deployed multi-tab web app.

---

## Tech Stack

| Layer | Tools |
|-------|-------|
| Language | R |
| Web Framework | Shiny |
| Data Source | RAWG Video Games Database API |
| Recommendation Engine | TF-IDF vectorization + cosine similarity |
| Visualization | `plotly`, `ggplot2` |
| Deployment | shinyapps.io |

---

## Data Pipeline Architecture

```
RAWG REST API (400+ games)
        │
        ▼
  API Scraping (httr, pagination)
        │
        ▼
  Data Cleaning & Preprocessing
  (missing values, type normalization)
        │
        ▼
  Feature Engineering
  ├── Bayesian-weighted score
  ├── Popularity tier classification
  ├── Playtime bucketing
  └── Genre/platform/tag encoding
        │
        ▼
  TF-IDF Vectorization
  (on combined text features)
        │
        ▼
  Cosine Similarity Matrix
        │
        ▼
  Shiny Dashboard (AI assistance)
  (recommendations + trend visualizations)
```

---

## Recommendation Engine

The engine uses **content-based filtering** via TF-IDF cosine similarity:

1. **Feature construction** — each game's genres, tags, platforms, and descriptions are combined into a single text representation
2. **TF-IDF vectorization** — transforms text features into weighted term-frequency vectors
3. **Cosine similarity** — computes pairwise similarity scores across all 400+ games
4. **Ranking** — top-N most similar games returned, re-ranked by Bayesian-weighted score to balance similarity with quality

### Feature Engineering Details

| Feature | Method |
|---------|--------|
| Rating score | Bayesian-weighted average (shrinks low-count ratings toward the mean) |
| Popularity tier | Binned by ratings count (niche / mainstream / popular / blockbuster) |
| Playtime bucket | Short / medium / long / epic based on average hours |
| Metacritic score | Normalized and included as a quality signal |

---

## Key Dashboard Features

- **Recommendation tab** — input a game, get top-N similar titles with similarity scores and Bayesian ratings
- **Genre trends** — interactive Plotly chart of genre popularity over release years
- **Platform distribution** — breakdown of games by platform across the catalogue
- **Rating patterns** — score distributions and rating trends over time
- **Dynamic filters** — filter recommendations by genre, platform, playtime, and release era

---

## Project Structure

```
game_recommendation_system/
├── app.R                  # Shiny app entry point
├── global.R               # Data pipeline & similarity matrix computation
├── ui.R                   # Multi-tab dashboard UI
├── server.R               # Reactive server logic
├── R/
│   ├── scrape_rawg.R      # RAWG API ingestion & pagination
│   ├── preprocess.R       # Cleaning & feature engineering
│   ├── tfidf_engine.R     # TF-IDF vectorization & cosine similarity
│   └── scoring.R          # Bayesian weighting & popularity tiering
└── README.md
```

---

## Running Locally

```r
# Install dependencies
install.packages(c("shiny", "httr", "jsonlite", "dplyr", "tidytext",
                   "proxy", "ggplot2", "plotly", "stringr"))

# Clone and run
shiny::runApp("game_recommendation_system/")
```

> **Note:** A RAWG API key is required. Get one free at [rawg.io/apidocs](https://rawg.io/apidocs) and set it in `global.R`.

---

## Skills Demonstrated

- REST API integration with pagination handling
- ETL pipeline: API scraping → preprocessing → feature engineering → model → dashboard
- NLP feature engineering (TF-IDF vectorization)
- Content-based recommendation system design
- Bayesian scoring and statistical feature engineering
- Interactive multi-tab Shiny dashboard with Plotly
- Production deployment on shinyapps.io
