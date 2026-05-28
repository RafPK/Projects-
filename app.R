# ============================================================
# app.R  —  Game Recommendation Dashboard
# HOW TO PUBLISH:
#   1. Save this file as app.R inside its OWN folder, e.g.:
#        C:/Users/you/Documents/GameScope/app.R
#   2. Open app.R in RStudio
#   3. Click the blue Publish button (top-right of editor)
#   4. Choose shinyapps.io → publish ONLY this file
#
# The scraping scripts (01_ / 02_) stay in a separate folder.
# ============================================================

library(shiny)
library(shinydashboard)
library(DT)
library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(plotly)

# ── LOAD DATA (with demo fallback) ────────────────────────────
DATA_PROC_DIR <- "data/processed"

load_or_demo <- function() {
  needed <- c("games_clean.rds","genre_long.rds","platform_long.rds",
               "genre_summary.rds","year_summary.rds","platform_summary.rds",
               "recommendations_lookup.rds")
  all_exist <- all(file.exists(file.path(DATA_PROC_DIR, needed)))

  if (all_exist) {
    message("✓ Loading processed data from ", DATA_PROC_DIR)
    return(list(
      games     = readRDS(file.path(DATA_PROC_DIR, "games_clean.rds")),
      genre_df  = readRDS(file.path(DATA_PROC_DIR, "genre_long.rds")),
      plat_df   = readRDS(file.path(DATA_PROC_DIR, "platform_long.rds")),
      genre_sum = readRDS(file.path(DATA_PROC_DIR, "genre_summary.rds")),
      year_sum  = readRDS(file.path(DATA_PROC_DIR, "year_summary.rds")),
      plat_sum  = readRDS(file.path(DATA_PROC_DIR, "platform_summary.rds")),
      recs      = readRDS(file.path(DATA_PROC_DIR, "recommendations_lookup.rds"))
    ))
  }

  message("⚠ Processed data not found — loading built-in demo dataset.")
  message("  Run 01_scrape_games.R then 02_transform_games.R to use real data.")

  # ── DEMO DATA ────────────────────────────────────────────────
  set.seed(42)
  demo_games_raw <- tibble::tribble(
    ~id,  ~name,                        ~released,    ~rating, ~metacritic, ~playtime, ~ratings_count, ~genres,                    ~platforms,                   ~tags,                              ~esrb_rating,   ~background_image,
    1L,   "The Witcher 3: Wild Hunt",   "2015-05-19", 4.66,    93L,         46L,       7823L,          "RPG, Adventure",           "PC, PlayStation 4, Xbox One","open world, fantasy, story rich",  "Mature",       "https://media.rawg.io/media/games/618/618c2031a07bbff6b4f611f10b6bcdbc.jpg",
    2L,   "Red Dead Redemption 2",      "2018-10-26", 4.59,    97L,         50L,       6102L,          "Action, Adventure",        "PC, PlayStation 4, Xbox One","open world, western, story rich",  "Mature",       "https://media.rawg.io/media/games/511/5118aff5091cb3efec399c808f8c598f.jpg",
    3L,   "Elden Ring",                 "2022-02-25", 4.55,    96L,         57L,       5341L,          "RPG, Action",              "PC, PlayStation 5, Xbox",    "souls-like, open world, difficult","Mature",       "https://media.rawg.io/media/games/b29/b294fdd866dcdb643e7bab370a552855.jpg",
    4L,   "God of War",                 "2018-04-20", 4.62,    94L,         21L,       5980L,          "Action, Adventure",        "PC, PlayStation 4",          "mythology, story rich, action",    "Mature",       "https://media.rawg.io/media/games/4be/4be6a6ad0364751a96229c56bf69be73.jpg",
    5L,   "Hades",                      "2020-09-17", 4.43,    93L,         22L,       4210L,          "Action, Indie, RPG",       "PC, Nintendo Switch",        "roguelike, indie, mythology",      "Teen",         "https://media.rawg.io/media/games/1f4/1f47a270b8f241f1a46a182c4c1cd970.jpg",
    6L,   "Hollow Knight",              "2017-02-24", 4.41,    87L,         41L,       3870L,          "Action, Indie",            "PC, Nintendo Switch",        "metroidvania, indie, difficult",   "Everyone",     "https://media.rawg.io/media/games/4cf/4cfc6b7f1850590a4634e4beca8af5d8.jpg",
    7L,   "Celeste",                    "2018-01-25", 4.38,    94L,         9L,        2950L,          "Platformer, Indie",        "PC, Nintendo Switch",        "platformer, indie, difficult",     "Everyone",     "https://media.rawg.io/media/games/594/594a9cc2528ffe5f2a5f39c0278f3fc1.jpg",
    8L,   "Disco Elysium",              "2019-10-15", 4.45,    97L,         30L,       2340L,          "RPG, Adventure",           "PC, PlayStation 4",          "detective, narrative, choices",    "Mature",       "https://media.rawg.io/media/games/f46/f466571d536f2e3ea9e815ad17177501.jpg",
    9L,   "Sekiro: Shadows Die Twice",  "2019-03-22", 4.40,    90L,         28L,       3100L,          "Action, RPG",              "PC, PlayStation 4, Xbox One","souls-like, difficult, samurai",   "Mature",       "https://media.rawg.io/media/games/67f/67f62d1f062a6164f57575e0604ee9f6.jpg",
    10L,  "Stardew Valley",             "2016-02-26", 4.37,    89L,         53L,       4620L,          "Simulation, RPG, Indie",   "PC, Nintendo Switch",        "farming, relaxing, indie",         "Everyone",     "https://media.rawg.io/media/games/713/713269608dc8f2f40f5a670a14b2de94.jpg",
    11L,  "Portal 2",                   "2011-04-18", 4.62,    95L,         9L,        6510L,          "Puzzle, Shooter",          "PC, PlayStation 3, Xbox 360","puzzle, co-op, funny",             "Everyone 10+", "https://media.rawg.io/media/games/328/3283617cb7d75d67257522368a49da18.jpg",
    12L,  "Minecraft",                  "2009-05-10", 4.30,    NA_integer_, 75L,       8900L,          "Simulation, Indie",        "PC, Xbox, Mobile",           "sandbox, creative, survival",      "Everyone 10+", "https://media.rawg.io/media/games/b4e/b4e4c73d5aa4ec4b56f7ca37f8e0b3a7.jpg",
    13L,  "Cyberpunk 2077",             "2020-12-10", 4.12,    86L,         25L,       5670L,          "RPG, Action, Shooter",     "PC, PlayStation 5, Xbox",    "open world, cyberpunk, futuristic","Mature",       "https://media.rawg.io/media/games/26d/26d4437715bee60138dab4a7c8c59c92.jpg",
    14L,  "Dark Souls III",             "2016-03-24", 4.35,    89L,         32L,       3880L,          "Action, RPG",              "PC, PlayStation 4, Xbox One","souls-like, difficult, fantasy",   "Teen",         "https://media.rawg.io/media/games/da1/da1b267764d77221f07a4386b6548e5a.jpg",
    15L,  "Ori and the Blind Forest",   "2015-03-11", 4.28,    88L,         8L,        2210L,          "Platformer, Adventure, Indie","PC, Xbox One",             "metroidvania, beautiful, indie",   "Everyone",     "https://media.rawg.io/media/games/15c/15c95a4915f88a3e89c821526afe05fc.jpg",
    16L,  "Baldur's Gate 3",            "2023-08-03", 4.71,    96L,         100L,      9100L,          "RPG, Adventure",           "PC, PlayStation 5",          "dnd, fantasy, choices",            "Mature",       "https://media.rawg.io/media/games/699/69907ecf13f172e9e144069769c3be73.jpg",
    17L,  "Terraria",                   "2011-05-16", 4.36,    83L,         40L,       5400L,          "Action, Indie, Simulation","PC, Mobile, Nintendo Switch","sandbox, survival, indie",         "Everyone 10+", "https://media.rawg.io/media/games/f46/f4693d4e5e8528b94e6b02b3a16a12a2.jpg",
    18L,  "Mass Effect 2",              "2010-01-26", 4.52,    96L,         25L,       3700L,          "RPG, Action, Shooter",     "PC, Xbox 360, PlayStation 3","sci-fi, story rich, choices",      "Mature",       "https://media.rawg.io/media/games/3cf/3cff89996570cf29a10eb9cd967dcf45.jpg",
    19L,  "Undertale",                  "2015-09-15", 4.25,    92L,         7L,        2680L,          "RPG, Indie, Adventure",    "PC, Nintendo Switch",        "indie, narrative, choices",        "Everyone",     "https://media.rawg.io/media/games/7cf/7cfc9220b401b7a300e409e539c9afd5.jpg",
    20L,  "Half-Life 2",                "2004-11-16", 4.58,    96L,         15L,       5100L,          "Shooter, Action",          "PC",                         "fps, sci-fi, story rich",          "Mature",       "https://media.rawg.io/media/games/b8c/b8c243eaa0fbac8115e0cdccac3f91dc.jpg",
    21L,  "Divinity: Original Sin 2",   "2017-09-14", 4.47,    93L,         60L,       2980L,          "RPG, Strategy",            "PC, PlayStation 4, Xbox One","turn-based, fantasy, co-op",       "Mature",       "https://media.rawg.io/media/games/424/424facd40f4eb1f2794fe4d4faac8c40.jpg",
    22L,  "Cuphead",                    "2017-09-29", 4.21,    88L,         10L,       2450L,          "Platformer, Action, Indie","PC, Nintendo Switch, Xbox",  "difficult, art deco, boss rush",   "Everyone 10+", "https://media.rawg.io/media/games/8fc/8fcaeba023eff38b4bd62984c12e8538.jpg",
    23L,  "Factorio",                   "2020-08-14", 4.49,    90L,         200L,      2100L,          "Simulation, Strategy, Indie","PC",                        "automation, building, sandbox",    "Everyone",     "https://media.rawg.io/media/games/d5a/d5a24f9f71315427fa6e966fdd98dfa6.jpg",
    24L,  "Shadow of the Colossus",     "2005-10-18", 4.39,    91L,         7L,        2800L,          "Action, Adventure",        "PlayStation 4, PlayStation 2","boss rush, beautiful, atmospheric","Teen",         "https://media.rawg.io/media/games/741/7414dab8d5a2588fc99d24d4c61af7dd.jpg",
    25L,  "NieR: Automata",             "2017-02-23", 4.38,    88L,         22L,       3650L,          "Action, RPG",              "PC, PlayStation 4, Xbox One","action rpg, sci-fi, narrative",    "Mature",       "https://media.rawg.io/media/games/fc1/fc1307a2774506b5bd65d7e8424664a7.jpg"
  )

  games <- demo_games_raw %>%
    dplyr::mutate(
      released       = as.Date(released),
      release_year   = lubridate::year(released),
      release_decade = (release_year %/% 10) * 10,
      rating         = as.numeric(rating),
      metacritic     = as.integer(metacritic),
      playtime       = as.numeric(playtime),
      ratings_count  = as.numeric(ratings_count),
      global_mean    = mean(rating, na.rm = TRUE),
      vote_weight    = 50L,
      weighted_score = (rating * ratings_count + global_mean * vote_weight) /
                       (ratings_count + vote_weight),
      esrb_clean     = dplyr::case_when(
        is.na(esrb_rating)                            ~ "Not Rated",
        stringr::str_detect(esrb_rating,"Everyone 10")~ "Everyone 10+",
        stringr::str_detect(esrb_rating,"Everyone")   ~ "Everyone",
        stringr::str_detect(esrb_rating,"Teen")       ~ "Teen",
        stringr::str_detect(esrb_rating,"Mature")     ~ "Mature",
        TRUE ~ esrb_rating
      ),
      popularity_tier = dplyr::case_when(
        ratings_count >= 5000 ~ "Blockbuster",
        ratings_count >= 1000 ~ "Popular",
        ratings_count >= 200  ~ "Notable",
        TRUE                  ~ "Niche"
      ),
      playtime_bucket = dplyr::case_when(
        is.na(playtime) | playtime == 0 ~ "Unknown",
        playtime < 5    ~ "Short (<5h)",
        playtime < 15   ~ "Medium (5–15h)",
        playtime < 40   ~ "Long (15–40h)",
        TRUE            ~ "Very Long (40h+)"
      ),
      description = paste("A beloved", genres, "game."),
      developers  = "Various",
      publishers  = "Various",
      tba         = FALSE,
      reviews_count      = ratings_count %/% 3L,
      suggestions_count  = ratings_count %/% 5L,
      stores      = "Steam, GOG"
    )

  # Genre long
  genre_df <- games %>%
    dplyr::select(id, name, genres) %>%
    tidyr::separate_rows(genres, sep = ",\\s*") %>%
    dplyr::filter(genres != "") %>%
    dplyr::rename(genre = genres)

  # Platform long
  plat_df <- games %>%
    dplyr::select(id, name, platforms) %>%
    tidyr::separate_rows(platforms, sep = ",\\s*") %>%
    dplyr::filter(platforms != "") %>%
    dplyr::rename(platform = platforms)

  # Genre summary
  genre_sum <- genre_df %>%
    dplyr::group_by(genre) %>%
    dplyr::summarise(
      n_games    = dplyr::n(),
      avg_rating = round(mean(games$weighted_score[games$id %in% id], na.rm = TRUE), 2),
      .groups = "drop"
    ) %>%
    dplyr::arrange(dplyr::desc(n_games))

  # Year summary
  year_sum <- games %>%
    dplyr::group_by(release_year) %>%
    dplyr::summarise(
      n_games        = dplyr::n(),
      avg_rating     = round(mean(weighted_score, na.rm = TRUE), 2),
      avg_metacritic = round(mean(metacritic, na.rm = TRUE), 2),
      .groups = "drop"
    )

  # Platform summary
  plat_sum <- plat_df %>%
    dplyr::group_by(platform) %>%
    dplyr::summarise(n_games = dplyr::n(), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(n_games))

  # Simple tag-overlap similarity for demo
  tag_tokens <- stringr::str_split(games$tags, ",\\s*")
  n <- nrow(games)
  sim_mat <- matrix(0, n, n, dimnames = list(games$id, games$id))
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i == j) next
      a <- tag_tokens[[i]]; b <- tag_tokens[[j]]
      sim_mat[i,j] <- length(intersect(a,b)) / length(union(a,b))
    }
  }

  recs <- lapply(as.character(games$id), function(gid) {
    row <- sim_mat[gid, ]
    row[gid] <- -Inf
    names(sort(row, decreasing = TRUE)[1:min(10, n-1)])
  })
  names(recs) <- as.character(games$id)

  list(games=games, genre_df=genre_df, plat_df=plat_df,
       genre_sum=genre_sum, year_sum=year_sum, plat_sum=plat_sum, recs=recs)
}

dat      <- load_or_demo()
games    <- dat$games
genre_df <- dat$genre_df
plat_df  <- dat$plat_df
genre_sum<- dat$genre_sum
year_sum <- dat$year_sum
plat_sum <- dat$plat_sum
recs     <- dat$recs

# Derived helpers
all_genres    <- sort(unique(genre_df$genre))
all_platforms <- sort(unique(plat_df$platform))
all_esrb      <- sort(unique(games$esrb_clean))
year_range    <- range(games$release_year, na.rm = TRUE)

# ── THEME COLOURS ─────────────────────────────────────────────
CLR_BG      <- "#0d0f1a"
CLR_PANEL   <- "#161927"
CLR_ACCENT  <- "#7c3aed"   # violet
CLR_ACCENT2 <- "#06b6d4"   # cyan
CLR_TEXT    <- "#e2e8f0"
CLR_MUTED   <- "#64748b"

# ── HELPERS ───────────────────────────────────────────────────
score_bar <- function(score, max_score = 5) {
  pct <- round(score / max_score * 100)
  sprintf(
    '<div style="background:#1e2030;border-radius:4px;height:8px;width:120px;">
       <div style="background:#7c3aed;width:%d%%;height:8px;border-radius:4px;"></div>
     </div>', pct)
}

game_card_html <- function(g) {
  img_src <- if (!is.na(g$background_image)) g$background_image else
    "https://via.placeholder.com/300x170?text=No+Image"
  sprintf('
    <div style="background:#161927;border-radius:12px;overflow:hidden;
                box-shadow:0 4px 24px rgba(0,0,0,.4);margin-bottom:16px;">
      <img src="%s" style="width:100%%;height:160px;object-fit:cover;" onerror="this.src=\'https://via.placeholder.com/300x170?text=No+Image\'"/>
      <div style="padding:14px;">
        <div style="font-size:15px;font-weight:700;color:#e2e8f0;margin-bottom:4px;">%s</div>
        <div style="font-size:12px;color:#94a3b8;margin-bottom:8px;">%s · %s</div>
        <div style="font-size:12px;color:#7c3aed;">⭐ %.2f &nbsp;|&nbsp; 🕹️ %sh</div>
      </div>
    </div>',
    img_src, g$name,
    ifelse(is.na(g$released), "TBA", as.character(g$release_year)),
    ifelse(g$genres == "", "—", str_trunc(g$genres, 35)),
    g$weighted_score,
    ifelse(is.na(g$playtime) | g$playtime == 0, "?", g$playtime)
  )
}

# ── UI ────────────────────────────────────────────────────────
ui <- dashboardPage(
  skin = "black",
  dashboardHeader(
    title = span(
      icon("gamepad", style = "color:#7c3aed"),
      "GameScope", style = "font-family:'Georgia',serif;letter-spacing:1px;"
    )
  ),

  dashboardSidebar(
    sidebarMenu(
      id = "sidebar",
      menuItem("🔍 Find a Game",     tabName = "finder",  icon = icon("search")),
      menuItem("🎮 Recommendations", tabName = "recs",    icon = icon("magic")),
      menuItem("📊 Explore Data",    tabName = "explore", icon = icon("chart-bar")),
      menuItem("📋 Browse All",      tabName = "browse",  icon = icon("table"))
    ),
    tags$hr(),
    tags$div(style = "padding:10px 15px;color:#64748b;font-size:12px;",
      "Data: RAWG API", tags$br(),
      paste0(nrow(games), " games indexed")
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML(sprintf("
      body, .wrapper, .content-wrapper, .main-sidebar { background:%s !important; }
      .skin-black .main-header .logo, .skin-black .main-header .navbar { background:%s !important; border-bottom:1px solid #1e2030; }
      .box { background:%s !important; border:1px solid #1e2030 !important; border-radius:10px; }
      .box-header { background:%s !important; border-bottom:1px solid #1e2030 !important; }
      .box-title, h3, h4, label, .control-label { color:%s !important; }
      .form-control, .selectize-input { background:#1e2030 !important; color:%s !important; border-color:#2d3a4a !important; }
      .selectize-dropdown { background:#1e2030 !important; color:%s !important; }
      .nav-tabs-custom > .nav-tabs > li.active > a { background:%s !important; border-color:#7c3aed !important; color:#fff !important; }
      .dataTables_wrapper, table.dataTable { color:%s !important; background:%s !important; }
      table.dataTable thead th { background:#1e2030 !important; color:#94a3b8 !important; border-bottom:1px solid #2d3a4a !important; }
      table.dataTable tbody tr { background:%s !important; }
      table.dataTable tbody tr:hover { background:#1e2030 !important; }
      .small-box { border-radius:10px !important; }
      .btn-primary { background:%s !important; border-color:%s !important; }
      .slider-handle { background:%s !important; }
      .irs-bar, .irs-bar-edge { background:%s !important; border-color:%s !important; }
      .sidebar-menu li.active > a { background:rgba(124,58,237,.25) !important; border-left:3px solid #7c3aed !important; }
    ", CLR_BG, CLR_BG, CLR_PANEL, CLR_PANEL,
       CLR_TEXT, CLR_TEXT, CLR_TEXT,
       CLR_ACCENT,
       CLR_TEXT, CLR_PANEL, CLR_PANEL,
       CLR_ACCENT, CLR_ACCENT, CLR_ACCENT, CLR_ACCENT, CLR_ACCENT
    )))),

    tabItems(
      # ── TAB 1: FINDER ───────────────────────────────────────
      tabItem("finder",
        fluidRow(
          box(width = 3, title = "🎛️ Filters",
            selectInput("f_genre", "Genre", choices = c("All", all_genres), selected = "All"),
            selectInput("f_platform", "Platform", choices = c("All", all_platforms), selected = "All"),
            selectInput("f_esrb", "Age Rating", choices = c("All", all_esrb), selected = "All"),
            sliderInput("f_year", "Release Year",
                        min = year_range[1], max = year_range[2],
                        value = c(2010, year_range[2]), sep = ""),
            sliderInput("f_rating", "Min Rating", 0, 5, value = 3.5, step = 0.1),
            sliderInput("f_playtime", "Max Playtime (h)", 0, 200, value = 200, step = 5),
            selectInput("f_sort", "Sort By",
                        choices = c("Weighted Score"="weighted_score",
                                    "Raw Rating"="rating",
                                    "Metacritic"="metacritic",
                                    "# Ratings"="ratings_count",
                                    "Avg Playtime"="playtime",
                                    "Release Year"="release_year"),
                        selected = "weighted_score"),
            actionButton("go_find", "Apply Filters", class = "btn-primary btn-block")
          ),
          box(width = 9, title = "🎮 Games",
            uiOutput("finder_cards")
          )
        )
      ),

      # ── TAB 2: RECOMMENDATIONS ──────────────────────────────
      tabItem("recs",
        fluidRow(
          box(width = 4, title = "Pick a Game You Love",
            selectizeInput("rec_game", "Search for a game:",
                           choices = setNames(games$id, games$name),
                           options = list(placeholder = "Type to search...",
                                          maxItems = 1)),
            sliderInput("rec_n", "Number of Recommendations", 5, 20, 10, step = 1),
            actionButton("go_rec", "Get Recommendations", class = "btn-primary btn-block"),
            tags$hr(),
            uiOutput("seed_card")
          ),
          box(width = 8, title = "✨ Recommended For You",
            uiOutput("rec_cards")
          )
        )
      ),

      # ── TAB 3: EXPLORE ──────────────────────────────────────
      tabItem("explore",
        fluidRow(
          valueBoxOutput("vb_total"),
          valueBoxOutput("vb_avg_rating"),
          valueBoxOutput("vb_avg_playtime")
        ),
        fluidRow(
          box(width = 6, title = "Games by Genre",
            plotlyOutput("plot_genre", height = 320)
          ),
          box(width = 6, title = "Ratings Over Years",
            plotlyOutput("plot_year", height = 320)
          )
        ),
        fluidRow(
          box(width = 6, title = "Top Platforms",
            plotlyOutput("plot_platform", height = 300)
          ),
          box(width = 6, title = "Rating vs. Playtime",
            plotlyOutput("plot_scatter", height = 300)
          )
        )
      ),

      # ── TAB 4: BROWSE ALL ───────────────────────────────────
      tabItem("browse",
        box(width = 12, title = "📋 Full Game Database",
          DTOutput("browse_table")
        )
      )
    )
  )
)

# ── SERVER ────────────────────────────────────────────────────
server <- function(input, output, session) {

  # Helper: build themed ggplot
  themed_gg <- function() {
    theme_minimal(base_size = 12) +
      theme(
        plot.background  = element_rect(fill = CLR_PANEL, colour = NA),
        panel.background = element_rect(fill = CLR_PANEL, colour = NA),
        panel.grid.major = element_line(colour = "#1e2030"),
        panel.grid.minor = element_blank(),
        text             = element_text(colour = CLR_TEXT),
        axis.text        = element_text(colour = "#94a3b8"),
        plot.title       = element_text(colour = CLR_TEXT, face = "bold")
      )
  }

  # ── Filtered games (reactive) ──────────────────────────────
  filtered_games <- eventReactive(input$go_find, {
    df <- games

    if (input$f_genre != "All") {
      ids <- genre_df %>% filter(genre == input$f_genre) %>% pull(id)
      df <- df %>% filter(id %in% ids)
    }
    if (input$f_platform != "All") {
      ids <- plat_df %>% filter(platform == input$f_platform) %>% pull(id)
      df <- df %>% filter(id %in% ids)
    }
    if (input$f_esrb != "All") {
      df <- df %>% filter(esrb_clean == input$f_esrb)
    }

    df <- df %>%
      filter(
        release_year  >= input$f_year[1],
        release_year  <= input$f_year[2],
        weighted_score >= input$f_rating,
        is.na(playtime) | playtime <= input$f_playtime
      ) %>%
      arrange(desc(.data[[input$f_sort]]))

    df
  }, ignoreNULL = FALSE)

  # ── Finder cards ───────────────────────────────────────────
  output$finder_cards <- renderUI({
    df <- filtered_games()
    if (nrow(df) == 0) {
      return(tags$p("No games match the current filters.", style = "color:#94a3b8;padding:20px;"))
    }
    top50 <- head(df, 50)
    cards <- lapply(seq_len(nrow(top50)), function(i) {
      g <- top50[i, ]
      column(4, HTML(game_card_html(g)))
    })
    do.call(fluidRow, cards)
  })

  # ── Recommendation engine ──────────────────────────────────
  rec_result <- eventReactive(input$go_rec, {
    req(input$rec_game)
    gid   <- as.character(input$rec_game)
    top_n <- input$rec_n
    sim_ids <- recs[[gid]]
    if (is.null(sim_ids) || length(sim_ids) == 0) return(list(seed = NULL, recs = NULL))
    seed_game <- games %>% filter(id == as.integer(gid))
    rec_games <- games %>% filter(id %in% as.integer(head(sim_ids, top_n)))
    list(seed = seed_game, recs = rec_games)
  })

  output$seed_card <- renderUI({
    res <- rec_result()
    req(!is.null(res$seed))
    HTML(game_card_html(res$seed))
  })

  output$rec_cards <- renderUI({
    res <- rec_result()
    req(!is.null(res$recs))
    df <- res$recs
    if (nrow(df) == 0) return(tags$p("No recommendations found.", style = "color:#94a3b8;"))
    cards <- lapply(seq_len(nrow(df)), function(i) {
      column(4, HTML(game_card_html(df[i, ])))
    })
    do.call(fluidRow, cards)
  })

  # ── Value boxes ────────────────────────────────────────────
  output$vb_total <- renderValueBox({
    valueBox(formatC(nrow(games), big.mark = ","), "Games Indexed",
             icon = icon("database"), color = "purple")
  })
  output$vb_avg_rating <- renderValueBox({
    valueBox(round(mean(games$weighted_score, na.rm = TRUE), 2),
             "Average Weighted Score", icon = icon("star"), color = "blue")
  })
  output$vb_avg_playtime <- renderValueBox({
    valueBox(paste0(round(mean(games$playtime, na.rm = TRUE), 1), "h"),
             "Average Playtime", icon = icon("clock"), color = "teal")
  })

  # ── Genre bar chart ────────────────────────────────────────
  output$plot_genre <- renderPlotly({
    df <- genre_sum %>% slice_head(n = 15)
    p  <- ggplot(df, aes(x = reorder(genre, n_games), y = n_games,
                          fill = avg_rating,
                          text = paste0(genre, "\n", n_games, " games\nAvg score: ", avg_rating))) +
      geom_col() +
      scale_fill_gradient(low = CLR_ACCENT2, high = CLR_ACCENT) +
      coord_flip() + labs(x = NULL, y = "# Games", fill = "Avg\nScore") +
      themed_gg()
    ggplotly(p, tooltip = "text") %>%
      layout(paper_bgcolor = CLR_PANEL, plot_bgcolor = CLR_PANEL,
             font = list(color = CLR_TEXT))
  })

  # ── Year trend ─────────────────────────────────────────────
  output$plot_year <- renderPlotly({
    df <- year_sum %>% filter(release_year >= 1995)
    p  <- ggplot(df, aes(x = release_year,
                          text = paste0(release_year, "\n", n_games, " games\nAvg score: ", avg_rating))) +
      geom_line(aes(y = avg_rating), colour = CLR_ACCENT, size = 1) +
      geom_col(aes(y = n_games / max(n_games) * max(avg_rating) * 0.4),
               fill = CLR_ACCENT2, alpha = 0.3) +
      labs(x = "Year", y = "Avg Weighted Score") +
      themed_gg()
    ggplotly(p, tooltip = "text") %>%
      layout(paper_bgcolor = CLR_PANEL, plot_bgcolor = CLR_PANEL,
             font = list(color = CLR_TEXT))
  })

  # ── Platform bar ───────────────────────────────────────────
  output$plot_platform <- renderPlotly({
    df <- plat_sum %>% slice_head(n = 12)
    p  <- ggplot(df, aes(x = reorder(platform, n_games), y = n_games,
                          fill = n_games,
                          text = paste0(platform, "\n", n_games, " games"))) +
      geom_col() +
      scale_fill_gradient(low = "#312e81", high = CLR_ACCENT) +
      coord_flip() + labs(x = NULL, y = "# Games") + guides(fill = "none") +
      themed_gg()
    ggplotly(p, tooltip = "text") %>%
      layout(paper_bgcolor = CLR_PANEL, plot_bgcolor = CLR_PANEL,
             font = list(color = CLR_TEXT))
  })

  # ── Scatter: rating vs playtime ────────────────────────────
  output$plot_scatter <- renderPlotly({
    df <- games %>%
      filter(!is.na(playtime), playtime > 0, playtime < 150) %>%
      sample_n(min(300, nrow(.)))
    p  <- ggplot(df, aes(x = playtime, y = weighted_score,
                          colour = genres,
                          text = paste0(name, "\n", playtime, "h · Score: ", round(weighted_score, 2)))) +
      geom_point(alpha = 0.7, size = 2) +
      labs(x = "Avg Playtime (h)", y = "Weighted Score") +
      guides(colour = "none") +
      themed_gg()
    ggplotly(p, tooltip = "text") %>%
      layout(paper_bgcolor = CLR_PANEL, plot_bgcolor = CLR_PANEL,
             font = list(color = CLR_TEXT))
  })

  # ── Browse table ───────────────────────────────────────────
  output$browse_table <- renderDT({
    games %>%
      select(name, release_year, genres, platforms, esrb_clean,
             weighted_score, rating, metacritic, playtime, ratings_count, popularity_tier) %>%
      rename(
        Game = name, Year = release_year, Genres = genres,
        Platforms = platforms, ESRB = esrb_clean,
        Score = weighted_score, Rating = rating,
        Metacritic = metacritic, Playtime = playtime,
        `# Ratings` = ratings_count, Popularity = popularity_tier
      ) %>%
      mutate(Score = round(Score, 2), Rating = round(Rating, 2))
  },
  options = list(
    pageLength = 20,
    scrollX    = TRUE,
    dom        = "frtip",
    columnDefs = list(list(className = "dt-center", targets = "_all"))
  ),
  style     = "bootstrap",
  class     = "table-dark table-hover",
  selection = "none",
  rownames  = FALSE)
}

# ── RUN ───────────────────────────────────────────────────────
shinyApp(ui, server)
