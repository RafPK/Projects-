Game Recommendation System
A content-based game recommendation engine built in R — scraping live data from the RAWG Video Games Database API, engineering rich features, and serving personalized recommendations through an interactive Shiny dashboard.
🚀 Live App
----------------------------------------------------------------
Overview
This project tackles a real product problem: given a game a user enjoys, recommend similar titles from a catalogue of 400+ games using content-based filtering. The system combines API-scraped metadata, custom feature engineering, and TF-IDF cosine similarity to generate ranked recommendations — all served through a deployed multi-tab web app.
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
  Shiny Dashboard
  (recommendations + trend visualizations)
----------------------------------------------------------------

  The engine uses content-based filtering via TF-IDF cosine similarity:

Feature construction — each game's genres, tags, platforms, and descriptions are combined into a single text representation
TF-IDF vectorization — transforms text features into weighted term-frequency vectors
Cosine similarity — computes pairwise similarity scores across all 400+ games
Ranking — top-N most similar games returned, re-ranked by Bayesian-weighted score to balance similarity with quality
