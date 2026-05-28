# ============================================================
# 02_transform_games.R
# Game Recommendation Project — Data Transformation
# Reads raw scraped data, engineers features, builds similarity
# matrix, and saves analysis-ready objects for the Shiny app.
# ============================================================

library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(purrr)
library(readr)

DATA_RAW_DIR  <- "data/raw"
DATA_PROC_DIR <- "data/processed"
dir.create(DATA_PROC_DIR, recursive = TRUE, showWarnings = FALSE)

# ── 1. LOAD RAW DATA ──────────────────────────────────────────
message("Loading raw data...")
games   <- readRDS(file.path(DATA_RAW_DIR, "games_list.rds"))
details <- readRDS(file.path(DATA_RAW_DIR, "games_details.rds"))

# ── 2. MERGE & BASIC CLEANING ────────────────────────────────
message("Merging and cleaning...")

df <- games %>%
  left_join(details, by = "id") %>%
  mutate(
    released    = as.Date(released),
    release_year= year(released),
    release_decade = (release_year %/% 10) * 10,

    # Numeric cleansing
    rating        = as.numeric(rating),
    metacritic    = as.numeric(metacritic),
    playtime      = as.numeric(playtime),
    ratings_count = as.numeric(ratings_count),

    # Weighted score: Bayesian average (shrink toward global mean)
    # score = (R*v + C*m) / (v + m)  where m = min votes threshold
    global_mean   = mean(rating, na.rm = TRUE),
    vote_weight   = 50,                            # pseudo-count
    weighted_score = (rating * ratings_count + global_mean * vote_weight) /
                     (ratings_count + vote_weight),

    # Clean text fields
    genres    = str_replace_all(genres, "\\s*,\\s*", ", "),
    tags      = str_replace_all(tags,   "\\s*,\\s*", ", "),
    platforms = str_replace_all(platforms, "\\s*,\\s*", ", "),

    # ESRB bucket
    esrb_clean = case_when(
      is.na(esrb_rating)         ~ "Not Rated",
      str_detect(esrb_rating, "Everyone") ~ "Everyone",
      str_detect(esrb_rating, "Teen")     ~ "Teen",
      str_detect(esrb_rating, "Mature")   ~ "Mature",
      TRUE ~ esrb_rating
    ),

    # Popularity tier
    popularity_tier = case_when(
      ratings_count >= 5000 ~ "Blockbuster",
      ratings_count >= 1000 ~ "Popular",
      ratings_count >= 200  ~ "Notable",
      TRUE                  ~ "Niche"
    ),

    # Playtime bucket
    playtime_bucket = case_when(
      is.na(playtime) | playtime == 0 ~ "Unknown",
      playtime < 5    ~ "Short (<5h)",
      playtime < 15   ~ "Medium (5–15h)",
      playtime < 40   ~ "Long (15–40h)",
      TRUE            ~ "Very Long (40h+)"
    )
  ) %>%
  filter(!is.na(name), !is.na(rating)) %>%
  distinct(id, .keep_all = TRUE)

message("  Rows after cleaning: ", nrow(df))

# ── 3. GENRE & PLATFORM LONG TABLES ──────────────────────────
message("Building genre/platform tables...")

genre_long <- df %>%
  select(id, name, genres) %>%
  separate_rows(genres, sep = ",\\s*") %>%
  filter(genres != "") %>%
  rename(genre = genres)

platform_long <- df %>%
  select(id, name, platforms) %>%
  separate_rows(platforms, sep = ",\\s*") %>%
  filter(platforms != "") %>%
  rename(platform = platforms)

tag_long <- df %>%
  select(id, name, tags) %>%
  separate_rows(tags, sep = ",\\s*") %>%
  filter(tags != "") %>%
  rename(tag = tags)

# ── 4. CONTENT-BASED SIMILARITY (TF-IDF cosine on genres+tags) ──
message("Computing content similarity matrix...")

# Build a "document" per game: genres + tags combined string
df <- df %>%
  mutate(content_doc = paste(genres, tags, sep = " "))

# Manual TF-IDF on genre+tag tokens
build_tfidf_matrix <- function(docs, ids) {
  # Tokenize
  tokens <- str_split(docs, "[,\\s]+")
  tokens <- map(tokens, ~ tolower(str_trim(.x[.x != ""])))

  vocab <- sort(unique(unlist(tokens)))
  N     <- length(docs)

  # TF matrix (term frequency)
  tf_mat <- matrix(0, nrow = N, ncol = length(vocab),
                   dimnames = list(ids, vocab))
  for (i in seq_len(N)) {
    toks <- tokens[[i]]
    if (length(toks) == 0) next
    tf <- table(toks) / length(toks)
    tf_mat[i, names(tf)] <- as.numeric(tf)
  }

  # IDF
  df_counts <- colSums(tf_mat > 0)
  idf       <- log((N + 1) / (df_counts + 1)) + 1   # smoothed

  # TF-IDF
  tfidf_mat <- sweep(tf_mat, 2, idf, "*")

  # L2-normalise rows
  norms <- sqrt(rowSums(tfidf_mat^2))
  norms[norms == 0] <- 1
  tfidf_mat <- tfidf_mat / norms

  tfidf_mat
}

tfidf <- build_tfidf_matrix(df$content_doc, as.character(df$id))

# Cosine similarity = dot product of normalised rows
# For large datasets compute lazily in the app; here we store the matrix
# (400 × 400 = 160k cells, perfectly manageable)
sim_matrix <- tfidf %*% t(tfidf)

message("  Similarity matrix: ", nrow(sim_matrix), " × ", ncol(sim_matrix))

# ── 5. TOP-N RECOMMENDATIONS LOOKUP TABLE ────────────────────
message("Building recommendation lookup...")

get_top_similar <- function(game_id, n = 10) {
  idx <- which(rownames(sim_matrix) == as.character(game_id))
  if (length(idx) == 0) return(character(0))
  sims <- sim_matrix[idx, ]
  sims[idx] <- -Inf   # exclude self
  top_ids <- names(sort(sims, decreasing = TRUE)[seq_len(n)])
  top_ids
}

recommendations_lookup <- map(df$id, function(gid) {
  get_top_similar(gid, n = 10)
}) %>% set_names(as.character(df$id))

# ── 6. SUMMARY STATS FOR DASHBOARD ───────────────────────────
message("Computing summary statistics...")

genre_summary <- genre_long %>%
  group_by(genre) %>%
  summarise(
    n_games      = n(),
    avg_rating   = round(mean(df$weighted_score[df$id %in% id], na.rm = TRUE), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(n_games))

year_summary <- df %>%
  filter(!is.na(release_year), release_year >= 1990) %>%
  group_by(release_year) %>%
  summarise(
    n_games    = n(),
    avg_rating = round(mean(weighted_score, na.rm = TRUE), 2),
    avg_metacritic = round(mean(metacritic, na.rm = TRUE), 2),
    .groups = "drop"
  )

platform_summary <- platform_long %>%
  group_by(platform) %>%
  summarise(n_games = n(), .groups = "drop") %>%
  arrange(desc(n_games)) %>%
  slice_head(n = 20)

# ── 7. SAVE ALL PROCESSED OBJECTS ────────────────────────────
message("Saving processed data...")

saveRDS(df,                    file.path(DATA_PROC_DIR, "games_clean.rds"))
saveRDS(genre_long,            file.path(DATA_PROC_DIR, "genre_long.rds"))
saveRDS(platform_long,         file.path(DATA_PROC_DIR, "platform_long.rds"))
saveRDS(tag_long,              file.path(DATA_PROC_DIR, "tag_long.rds"))
saveRDS(sim_matrix,            file.path(DATA_PROC_DIR, "sim_matrix.rds"))
saveRDS(recommendations_lookup,file.path(DATA_PROC_DIR, "recommendations_lookup.rds"))
saveRDS(genre_summary,         file.path(DATA_PROC_DIR, "genre_summary.rds"))
saveRDS(year_summary,          file.path(DATA_PROC_DIR, "year_summary.rds"))
saveRDS(platform_summary,      file.path(DATA_PROC_DIR, "platform_summary.rds"))

write_csv(df, file.path(DATA_PROC_DIR, "games_clean.csv"))

message("\n✓ Transformation complete. Files saved to: ", DATA_PROC_DIR)
message("  games_clean        — ", nrow(df), " games")
message("  genre_long         — ", nrow(genre_long), " rows")
message("  sim_matrix         — ", nrow(sim_matrix), "×", ncol(sim_matrix))
message("  recommendations_lookup — ", length(recommendations_lookup), " entries")
