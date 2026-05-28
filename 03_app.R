# ============================================================
# 03_app.R
# Game Recommendation Project — Shiny Dashboard
# Run: shiny::runApp("03_app.R")
# Deploy: rsconnect::deployApp(appFiles = c("03_app.R","data/"))
# ============================================================

library(shiny)
library(shinydashboard)
library(DT)
library(ggplot2)
library(dplyr)
library(stringr)
library(plotly)

# ── LOAD DATA ─────────────────────────────────────────────────
DATA_PROC_DIR <- "data/processed"

games    <- readRDS(file.path(DATA_PROC_DIR, "games_clean.rds"))
genre_df <- readRDS(file.path(DATA_PROC_DIR, "genre_long.rds"))
plat_df  <- readRDS(file.path(DATA_PROC_DIR, "platform_long.rds"))
genre_sum<- readRDS(file.path(DATA_PROC_DIR, "genre_summary.rds"))
year_sum <- readRDS(file.path(DATA_PROC_DIR, "year_summary.rds"))
plat_sum <- readRDS(file.path(DATA_PROC_DIR, "platform_summary.rds"))
recs     <- readRDS(file.path(DATA_PROC_DIR, "recommendations_lookup.rds"))

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
