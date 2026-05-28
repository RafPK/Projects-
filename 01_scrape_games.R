# ============================================================
# 01_scrape_games.R
# Game Recommendation Project — Data Scraping
# Source: RAWG Video Games Database API (https://rawg.io/apidocs)
# Free API key: https://rawg.io/login?forward=developer
# ============================================================

library(httr)
library(jsonlite)
library(dplyr)
library(purrr)

# ── CONFIG ────────────────────────────────────────────────────
# Register for a free key at https://rawg.io/login?forward=developer
# then replace the string below or set env var RAWG_API_KEY
RAWG_API_KEY <- Sys.getenv("RAWG_API_KEY", unset = "5f526b1c609941bfbb1f67a7f3136731")
BASE_URL      <- "https://api.rawg.io/api"
DATA_RAW_DIR  <- "data/raw"

dir.create(DATA_RAW_DIR, recursive = TRUE, showWarnings = FALSE)

# ── HELPERS ───────────────────────────────────────────────────

#' Safe GET wrapper with retry on rate-limit (429)
safe_get <- function(url, query = list(), max_retries = 3) {
  query$key <- RAWG_API_KEY
  for (i in seq_len(max_retries)) {
    resp <- GET(url, query = query)
    if (status_code(resp) == 429) {
      wait <- 2^i
      message(glue::glue("Rate limited. Waiting {wait}s ..."))
      Sys.sleep(wait)
      next
    }
    stop_for_status(resp)
    return(content(resp, as = "parsed", simplifyVector = FALSE))
  }
  stop("Max retries exceeded for: ", url)
}

#' Fetch one page of games and return a flat data.frame
fetch_game_page <- function(page = 1, page_size = 40,
                            ordering = "-rating",
                            genres = NULL,
                            min_ratings = 20) {
  query <- list(
    page       = page,
    page_size  = page_size,
    ordering   = ordering,
    ratings_count = min_ratings
  )
  if (!is.null(genres)) query$genres <- genres

  raw <- safe_get(file.path(BASE_URL, "games"), query)

  games <- raw$results
  if (length(games) == 0) return(NULL)

  map_dfr(games, function(g) {
    tibble(
      id              = g$id %||% NA_integer_,
      slug            = g$slug %||% NA_character_,
      name            = g$name %||% NA_character_,
      released        = g$released %||% NA_character_,
      tba             = g$tba %||% NA,
      background_image= g$background_image %||% NA_character_,
      rating          = g$rating %||% NA_real_,
      rating_top      = g$rating_top %||% NA_integer_,
      ratings_count   = g$ratings_count %||% NA_integer_,
      reviews_count   = g$reviews_count %||% NA_integer_,
      metacritic      = g$metacritic %||% NA_integer_,
      playtime        = g$playtime %||% NA_integer_,    # avg hours
      suggestions_count = g$suggestions_count %||% NA_integer_,
      genres          = paste(map_chr(g$genres %||% list(), "name"), collapse = ", "),
      platforms       = paste(map_chr(g$platforms %||% list(),
                                      ~ .x$platform$name %||% ""), collapse = ", "),
      tags            = paste(head(map_chr(g$tags %||% list(), "name"), 10), collapse = ", "),
      esrb_rating     = g$esrb_rating$name %||% NA_character_,
      stores          = paste(map_chr(g$stores %||% list(),
                                      ~ .x$store$name %||% ""), collapse = ", ")
    )
  })
}

#' Fetch detailed info for a single game (description, developers, publishers)
fetch_game_detail <- function(game_id) {
  raw <- safe_get(file.path(BASE_URL, "games", game_id))
  tibble(
    id           = raw$id,
    description  = raw$description_raw %||% NA_character_,
    developers   = paste(map_chr(raw$developers %||% list(), "name"), collapse = ", "),
    publishers   = paste(map_chr(raw$publishers %||% list(), "name"), collapse = ", "),
    website      = raw$website %||% NA_character_
  )
}

# ── SCRAPE GAME LIST ─────────────────────────────────────────
message("=== Scraping game list ===")

# Collect top-rated games across popular genres
target_pages <- 10   # 10 pages × 40 games = 400 games (adjust as needed)

all_games <- map_dfr(seq_len(target_pages), function(p) {
  message("  Fetching page ", p, " ...")
  df <- fetch_game_page(page = p, page_size = 40, ordering = "-rating")
  Sys.sleep(0.5)  # be polite to the API
  df
})

all_games <- all_games %>% distinct(id, .keep_all = TRUE)
message("Total unique games fetched: ", nrow(all_games))

saveRDS(all_games, file.path(DATA_RAW_DIR, "games_list.rds"))
write.csv(all_games, file.path(DATA_RAW_DIR, "games_list.csv"), row.names = FALSE)

# ── SCRAPE GAME DETAILS ───────────────────────────────────────
message("\n=== Scraping game details ===")

game_ids <- all_games$id

details_list <- map(seq_along(game_ids), function(i) {
  id <- game_ids[i]
  if (i %% 20 == 0) message("  Detail ", i, "/", length(game_ids))
  tryCatch({
    d <- fetch_game_detail(id)
    Sys.sleep(0.4)
    d
  }, error = function(e) {
    warning("Failed for id ", id, ": ", e$message)
    tibble(id = id, description = NA_character_,
           developers = NA_character_, publishers = NA_character_,
           website = NA_character_)
  })
})

details_df <- bind_rows(details_list)

saveRDS(details_df, file.path(DATA_RAW_DIR, "games_details.rds"))
write.csv(details_df, file.path(DATA_RAW_DIR, "games_details.csv"), row.names = FALSE)

message("\n✓ Scraping complete. Files saved to: ", DATA_RAW_DIR)
message("  games_list.rds / .csv    — ", nrow(all_games), " rows")
message("  games_details.rds / .csv — ", nrow(details_df), " rows")

