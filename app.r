
library(shiny)
library(bslib)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)
library(lubridate)
library(purrr)

# ---- Load data -----------------------------------------------
message("Loading transformed data...")
td      <- readRDS("weather_transformed.rds")
scraped <- readRDS("weather_scraped.rds")

current  <- td$current_enriched
stats    <- td$model_stats
preds    <- td$predictions_24h
coefs    <- td$coef_table
resids   <- td$residuals_df
hourly   <- td$hourly_clean
cities   <- scraped$city_meta

city_choices <- sort(unique(current$city))

# ---- Weather code → description ------------------------------
wmo_description <- function(code) {
  case_when(
    code == 0                  ~ "Clear Sky ☀️",
    code %in% 1:3              ~ "Partly Cloudy ⛅",
    code %in% 45:48            ~ "Foggy 🌫️",
    code %in% 51:57            ~ "Drizzle 🌦️",
    code %in% 61:67            ~ "Rain 🌧️",
    code %in% 71:77            ~ "Snow ❄️",
    code %in% 80:82            ~ "Rain Showers 🌨️",
    code %in% 95:99            ~ "Thunderstorm ⛈️",
    TRUE                       ~ "Variable 🌡️"
  )
}

current <- current %>%
  mutate(weather_desc = wmo_description(weather_code))

# ---- Colour palette ------------------------------------------
palette <- c(
  bg        = "#0d1117",
  surface   = "#161b22",
  card      = "#1c2128",
  border    = "#30363d",
  accent1   = "#58a6ff",   # electric blue
  accent2   = "#3fb950",   # green
  accent3   = "#f78166",   # coral
  accent4   = "#d2a8ff",   # lavender
  text      = "#e6edf3",
  muted     = "#8b949e"
)

# ---- Custom CSS ----------------------------------------------
custom_css <- sprintf('
@import url("https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap");

* { box-sizing: border-box; }

body, .shiny-page {
  background: %s !important;
  color: %s !important;
  font-family: "Space Grotesk", sans-serif;
}

/* ---------- Scrollbar ---------- */
::-webkit-scrollbar { width: 6px; }
::-webkit-scrollbar-track { background: %s; }
::-webkit-scrollbar-thumb { background: %s; border-radius: 3px; }

/* ---------- Cards ---------- */
.wx-card {
  background: %s;
  border: 1px solid %s;
  border-radius: 12px;
  padding: 20px 24px;
  margin-bottom: 16px;
  transition: border-color .2s;
}
.wx-card:hover { border-color: %s; }

/* ---------- Header ---------- */
.wx-header {
  background: linear-gradient(135deg, #0d1117 0%%, #161b22 50%%, #0d1117 100%%);
  border-bottom: 1px solid %s;
  padding: 24px 32px;
  display: flex;
  align-items: center;
  gap: 16px;
  margin-bottom: 0;
}
.wx-title { font-size: 1.6rem; font-weight: 700; color: %s; margin: 0; letter-spacing: -.5px; }
.wx-subtitle { font-size: .85rem; color: %s; margin: 0; }
.wx-badge {
  background: %s22;
  border: 1px solid %s44;
  border-radius: 20px;
  padding: 4px 12px;
  font-size: .75rem;
  color: %s;
  font-family: "JetBrains Mono", monospace;
}

/* ---------- Stat boxes ---------- */
.stat-row { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 16px; }
.stat-box {
  flex: 1; min-width: 130px;
  background: %s;
  border: 1px solid %s;
  border-radius: 10px;
  padding: 14px 16px;
  text-align: center;
}
.stat-value { font-size: 1.7rem; font-weight: 700; color: %s; font-family: "JetBrains Mono", monospace; }
.stat-label { font-size: .72rem; color: %s; margin-top: 2px; text-transform: uppercase; letter-spacing: .05em; }

/* ---------- City selector ---------- */
.selectize-control .selectize-input {
  background: %s !important;
  border: 1px solid %s !important;
  color: %s !important;
  border-radius: 8px !important;
  box-shadow: none !important;
}
.selectize-dropdown {
  background: %s !important;
  border: 1px solid %s !important;
  color: %s !important;
}
.selectize-dropdown .option:hover,
.selectize-dropdown .option.active { background: %s22 !important; }

/* ---------- Tabs ---------- */
.nav-pills .nav-link {
  color: %s !important;
  border-radius: 8px !important;
  padding: 6px 14px !important;
  font-size: .85rem !important;
}
.nav-pills .nav-link.active {
  background: %s !important;
  color: #fff !important;
}

/* ---------- Tables ---------- */
.dataTables_wrapper, table.dataTable {
  background: transparent !important;
  color: %s !important;
  font-size: .82rem;
}
table.dataTable thead th {
  background: %s !important;
  color: %s !important;
  border-bottom: 1px solid %s !important;
  font-weight: 600;
  font-size: .78rem;
  letter-spacing: .04em;
  text-transform: uppercase;
}
table.dataTable tbody tr { background: transparent !important; }
table.dataTable tbody tr:hover td { background: %s11 !important; }
table.dataTable tbody td { border-color: %s !important; }

/* ---------- Refresh button ---------- */
.wx-btn {
  background: %s;
  border: none;
  color: #fff;
  border-radius: 8px;
  padding: 8px 20px;
  font-family: "Space Grotesk", sans-serif;
  font-size: .85rem;
  font-weight: 600;
  cursor: pointer;
  transition: opacity .2s;
}
.wx-btn:hover { opacity: .85; }

/* ---------- Section labels ---------- */
.section-label {
  font-size: .7rem;
  font-weight: 600;
  letter-spacing: .1em;
  text-transform: uppercase;
  color: %s;
  margin-bottom: 8px;
}

/* ---------- Metric pill ---------- */
.metric-pill {
  display: inline-block;
  background: %s22;
  border: 1px solid %s44;
  border-radius: 6px;
  padding: 3px 10px;
  font-size: .78rem;
  color: %s;
  font-family: "JetBrains Mono", monospace;
  margin: 2px;
}

/* ---------- Plot backgrounds ---------- */
.plotly, .js-plotly-plot { background: transparent !important; }

/* ---------- Sidebar ---------- */
.wx-sidebar {
  background: %s;
  border-right: 1px solid %s;
  padding: 20px 16px;
  height: 100%%;
}
',
  palette["bg"], palette["text"],
  palette["surface"], palette["border"],
  palette["card"], palette["border"], palette["accent1"],
  palette["border"], palette["text"], palette["muted"],
  palette["accent1"], palette["accent1"], palette["accent1"],
  palette["card"], palette["border"], palette["accent1"], palette["muted"],
  palette["card"], palette["border"], palette["text"],
  palette["card"], palette["border"], palette["text"], palette["accent1"],
  palette["muted"], palette["accent1"],
  palette["text"],
  palette["surface"], palette["muted"], palette["border"],
  palette["accent1"], palette["border"],
  palette["accent1"],
  palette["muted"],
  palette["accent2"], palette["accent2"], palette["accent2"],
  palette["surface"], palette["border"]
)

# ---- Plot helpers --------------------------------------------
theme_wx <- function() {
  theme_minimal(base_family = "Space Grotesk") +
  theme(
    plot.background    = element_rect(fill = "transparent", color = NA),
    panel.background   = element_rect(fill = "transparent", color = NA),
    panel.grid.major   = element_line(color = "#30363d", linewidth = .3),
    panel.grid.minor   = element_blank(),
    axis.text          = element_text(color = "#8b949e", size = 9),
    axis.title         = element_text(color = "#8b949e", size = 10),
    plot.title         = element_text(color = "#e6edf3", size = 13, face = "bold"),
    plot.subtitle      = element_text(color = "#8b949e", size = 10),
    legend.background  = element_blank(),
    legend.text        = element_text(color = "#8b949e"),
    legend.title       = element_text(color = "#8b949e"),
    strip.text         = element_text(color = "#e6edf3", size = 9),
    plot.margin        = margin(10, 10, 10, 10)
  )
}

ggplotly_wx <- function(p, ...) {
  ggplotly(p, ...) %>%
    layout(
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor  = "rgba(0,0,0,0)",
      font          = list(color = "#e6edf3", family = "Space Grotesk"),
      xaxis         = list(gridcolor = "#30363d", zerolinecolor = "#30363d"),
      yaxis         = list(gridcolor = "#30363d", zerolinecolor = "#30363d"),
      legend        = list(bgcolor = "rgba(0,0,0,0)")
    ) %>%
    config(displayModeBar = FALSE)
}

# ==============================================================
# UI
# ==============================================================
ui <- fluidPage(
  tags$head(
    tags$style(HTML(custom_css)),
    tags$title("WeatherML Americas")
  ),

  # ---- Header ----
  div(class = "wx-header",
    div(style = "font-size:2rem;", "🌎"),
    div(
      h1("WeatherML Americas", class = "wx-title"),
      p("Real-Time Linear Regression Weather Forecasting", class = "wx-subtitle")
    ),
    div(style = "margin-left:auto; display:flex; align-items:center; gap:10px;",
      span(class = "wx-badge", paste("Scraped:", format(scraped$scraped_at, "%b %d %H:%M UTC"))),
      actionButton("refresh_btn", "↻ Refresh Data", class = "wx-btn",
                   style = sprintf("background:%s;", palette["accent1"]))
    )
  ),

  # ---- Body ----
  div(style = "padding: 20px 24px;",

    # === ROW 1: Global stats ===
    div(class = "stat-row",
      div(class = "stat-box",
        div(class = "stat-value", nrow(current)),
        div(class = "stat-label", "Cities Tracked")
      ),
      div(class = "stat-box",
        div(class = "stat-value", style = sprintf("color:%s;", palette["accent2"]),
            sprintf("%.2f", mean(stats$r_squared, na.rm = TRUE))),
        div(class = "stat-label", "Avg R²")
      ),
      div(class = "stat-box",
        div(class = "stat-value", style = sprintf("color:%s;", palette["accent3"]),
            sprintf("%.1f°C", mean(current$current_temp, na.rm = TRUE))),
        div(class = "stat-label", "Avg Temp Now")
      ),
      div(class = "stat-box",
        div(class = "stat-value", style = sprintf("color:%s;", palette["accent4"]),
            sprintf("%.1f", mean(stats$rmse, na.rm = TRUE))),
        div(class = "stat-label", "Avg RMSE (°C)")
      ),
      div(class = "stat-box",
        div(class = "stat-value",
            format(scraped$scraped_at, "%H:%M")),
        div(class = "stat-label", "Last Update")
      )
    ),

    # === ROW 2: Left sidebar + main ===
    fluidRow(

      # Sidebar
      column(3,
        div(class = "wx-sidebar",
          div(class = "section-label", "Select City"),
          selectInput("selected_city", NULL,
                      choices = city_choices,
                      selected = "New York",
                      width = "100%"),

          hr(style = "border-color:#30363d; margin:16px 0;"),

          div(class = "section-label", "Current Conditions"),
          uiOutput("city_current_box"),

          hr(style = "border-color:#30363d; margin:16px 0;"),

          div(class = "section-label", "Model Performance"),
          uiOutput("city_model_box")
        )
      ),

      # Main panel
      column(9,
        navset_pill(

          # --- Tab 1: Forecast ---
          nav_panel("📈 Forecast",
            div(class = "wx-card",
              div(class = "section-label", "24-Hour Temperature Forecast — Linear Regression"),
              plotlyOutput("forecast_plot", height = "320px")
            ),
            fluidRow(
              column(6,
                div(class = "wx-card",
                  div(class = "section-label", "Actual vs Predicted (Last 7 Days)"),
                  plotlyOutput("actual_pred_plot", height = "260px")
                )
              ),
              column(6,
                div(class = "wx-card",
                  div(class = "section-label", "Hourly Temperature History"),
                  plotlyOutput("history_plot", height = "260px")
                )
              )
            )
          ),

          # --- Tab 2: All Cities ---
          nav_panel("🗺️ All Cities",
            div(class = "wx-card",
              div(class = "section-label", "Current Conditions Across the Americas"),
              DTOutput("all_cities_table")
            ),
            div(class = "wx-card",
              div(class = "section-label", "Temperature Distribution by City"),
              plotlyOutput("all_cities_boxplot", height = "360px")
            )
          ),

          # --- Tab 3: Regression ---
          nav_panel("📊 Regression",
            div(class = "wx-card",
              div(class = "section-label", "Residuals Diagnostic"),
              plotlyOutput("resid_plot", height = "280px")
            ),
            div(class = "wx-card",
              div(class = "section-label", "Model Coefficients (significant predictors)"),
              DTOutput("coef_table_out")
            )
          ),

          # --- Tab 4: Model Comparison ---
          nav_panel("🏆 Model Rankings",
            div(class = "wx-card",
              div(class = "section-label", "R² and RMSE by City"),
              plotlyOutput("model_ranking_plot", height = "400px")
            ),
            div(class = "wx-card",
              div(class = "section-label", "Full Model Statistics"),
              DTOutput("model_stats_table")
            )
          )
        )
      )
    )
  )
)

# ==============================================================
# SERVER
# ==============================================================
server <- function(input, output, session) {

  # ---- Reactive city data ----
  r_city_stats <- reactive({
    stats %>% filter(city == input$selected_city)
  })
  r_city_current <- reactive({
    current %>% filter(city == input$selected_city)
  })
  r_city_preds <- reactive({
    preds %>% filter(city == input$selected_city)
  })
  r_city_hourly <- reactive({
    hourly %>% filter(city == input$selected_city)
  })
  r_city_resids <- reactive({
    resids %>% filter(city == input$selected_city)
  })
  r_city_coefs <- reactive({
    coefs %>%
      filter(city == input$selected_city, predictor != "(Intercept)") %>%
      arrange(p_value)
  })

  # ---- Sidebar: current conditions ----
  output$city_current_box <- renderUI({
    d <- r_city_current()
    if (nrow(d) == 0) return(NULL)

    mk <- function(val, label, color = palette["accent1"]) {
      div(style = "margin-bottom:8px;",
        div(style = sprintf("font-size:1.4rem;font-weight:700;color:%s;font-family:'JetBrains Mono',monospace;", color), val),
        div(style = "font-size:.72rem;color:#8b949e;text-transform:uppercase;letter-spacing:.05em;", label)
      )
    }

    div(
      mk(sprintf("%.1f°C", d$current_temp),  "Temperature"),
      mk(sprintf("%.1f°C", d$current_apparent_temp), "Feels Like", palette["accent4"]),
      mk(sprintf("%d%%",   d$current_humidity), "Humidity",   palette["accent2"]),
      mk(sprintf("%.1f km/h", d$current_wind), "Wind Speed", palette["accent3"]),
      mk(sprintf("%.0f hPa",  d$current_pressure), "Pressure"),
      div(style = sprintf("margin-top:12px;font-size:.85rem;color:%s;", palette["accent2"]),
          d$weather_desc)
    )
  })

  # ---- Sidebar: model stats ----
  output$city_model_box <- renderUI({
    s <- r_city_stats()
    if (nrow(s) == 0) return(NULL)

    mk_pill <- function(val, label) {
      div(style = "margin-bottom:6px;",
        span(class = "metric-pill", val),
        span(style = "font-size:.72rem;color:#8b949e;margin-left:6px;", label)
      )
    }
    div(
      mk_pill(sprintf("%.4f", s$r_squared),  "R²"),
      mk_pill(sprintf("%.4f", s$adj_r2),     "Adj R²"),
      mk_pill(sprintf("%.3f°C", s$rmse),     "RMSE"),
      mk_pill(sprintf("%.3f°C", s$mae),      "MAE"),
      mk_pill(sprintf("%d", s$n_obs),        "Obs")
    )
  })

  # ---- Tab 1: Forecast plot ----
  output$forecast_plot <- renderPlotly({
    d    <- r_city_preds()
    curr <- r_city_current()
    if (nrow(d) == 0) return(NULL)

    # Drop rows where predictions are non-finite
    d <- d %>%
      filter(
        is.finite(pred_temp),
        is.finite(lower_95),
        is.finite(upper_95)
      )
    if (nrow(d) == 0) return(NULL)

    curr_temp <- if (is.finite(curr$current_temp)) curr$current_temp else NA_real_

    p <- ggplot(d, aes(x = datetime)) +
      geom_ribbon(aes(ymin = lower_95, ymax = upper_95),
                  fill = palette["accent1"], alpha = .12) +
      geom_line(aes(y = pred_temp), color = palette["accent1"],
                linewidth = 1.1) +
      geom_point(aes(y = pred_temp), color = palette["accent1"],
                 size = 2, alpha = .8)

    # Only add current-temp reference line if value is valid
    if (!is.na(curr_temp)) {
      p <- p +
        geom_hline(yintercept = curr_temp, color = palette["accent3"],
                   linetype = "dashed", linewidth = .6) +
        annotate("text", x = min(d$datetime), y = curr_temp + .5,
                 label = sprintf("Now: %.1f°C", curr_temp),
                 color = palette["accent3"], size = 3.2, hjust = 0)
    }

    p <- p +
      labs(x = NULL, y = "Temperature (°C)",
           title = sprintf("%s — Next 24 Hours", input$selected_city),
           subtitle = "95% prediction interval shown") +
      theme_wx()

    ggplotly_wx(p, tooltip = c("x", "y"))
  })

  # ---- Tab 1: Actual vs Predicted ----
  output$actual_pred_plot <- renderPlotly({
    r <- r_city_resids()
    if (nrow(r) == 0) return(NULL)

    # Remove non-finite rows before computing range
    r <- r %>% filter(is.finite(actual), is.finite(fitted))
    if (nrow(r) == 0) return(NULL)

    lim <- range(c(r$actual, r$fitted), na.rm = TRUE)
    # Safety: ensure lim is finite and has a real spread
    if (any(!is.finite(lim)) || diff(lim) == 0) lim <- c(lim[1] - 1, lim[2] + 1)

    p <- ggplot(r, aes(x = actual, y = fitted)) +
      geom_point(color = palette["accent1"], alpha = .35, size = 1.2) +
      geom_abline(slope = 1, intercept = 0,
                  color = palette["accent3"], linetype = "dashed") +
      coord_equal(xlim = lim, ylim = lim) +
      labs(x = "Actual (°C)", y = "Predicted (°C)",
           title = "Actual vs Predicted Temperature") +
      theme_wx()

    ggplotly_wx(p)
  })

  # ---- Tab 1: History plot ----
  output$history_plot <- renderPlotly({
    h <- r_city_hourly() %>%
      arrange(datetime) %>%
      tail(7 * 24)   # last 7 days
    if (nrow(h) == 0) return(NULL)

    p <- ggplot(h, aes(x = datetime, y = temperature)) +
      geom_line(color = palette["accent2"], linewidth = .8, alpha = .9) +
      geom_area(fill = palette["accent2"], alpha = .08) +
      labs(x = NULL, y = "Temperature (°C)",
           title = "7-Day Temperature History") +
      theme_wx()

    ggplotly_wx(p)
  })

  # ---- Tab 2: All cities table ----
  output$all_cities_table <- renderDT({
    current %>%
      select(
        City        = city,
        Country     = country,
        `Temp (°C)` = current_temp,
        `Feels Like`= current_apparent_temp,
        `Humidity %`= current_humidity,
        `Wind km/h` = current_wind,
        `Pressure`  = current_pressure,
        Conditions  = weather_desc,
        `6h Pred`   = pred_6h,
        `24h Pred`  = pred_24h,
        `R²`        = r_squared
      ) %>%
      mutate(across(where(is.numeric), ~ round(.x, 1))) %>%
      datatable(
        options   = list(pageLength = 10, scrollX = TRUE,
                         dom = "ftp",
                         initComplete = JS("function(settings, json) {",
                           "$('body').css({'background-color':'#0d1117'});","}")),
        rownames  = FALSE,
        selection = "none",
        class     = "compact"
      ) %>%
      formatStyle(
        "Temp (°C)",
        background = styleColorBar(range(current$current_temp, na.rm = TRUE),
                                   color = "#58a6ff44"),
        backgroundSize  = "100% 80%",
        backgroundRepeat = "no-repeat",
        backgroundPosition = "center"
      )
  })

  # ---- Tab 2: Box plot ----
  output$all_cities_boxplot <- renderPlotly({
    h_top <- hourly %>%
      filter(city %in% city_choices) %>%
      group_by(city) %>%
      filter(n() > 20) %>% ungroup()

    ord <- h_top %>%
      group_by(city) %>%
      summarise(med = median(temperature, na.rm = TRUE)) %>%
      arrange(med) %>% pull(city)

    p <- ggplot(h_top, aes(x = factor(city, ord), y = temperature,
                            fill = city)) +
      geom_boxplot(alpha = .7, outlier.size = .6,
                   outlier.color = palette["muted"],
                   color = palette["border"]) +
      scale_fill_viridis_d(option = "turbo", guide = "none") +
      labs(x = NULL, y = "Temperature (°C)") +
      theme_wx() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8))

    ggplotly_wx(p)
  })

  # ---- Tab 3: Residuals ----
  output$resid_plot <- renderPlotly({
    r <- r_city_resids()
    if (nrow(r) == 0) return(NULL)

    p <- ggplot(r, aes(x = fitted, y = residuals)) +
      geom_hline(yintercept = 0, color = palette["accent3"],
                 linetype = "dashed") +
      geom_point(aes(color = abs(residuals)), alpha = .45, size = 1.5) +
      scale_color_gradient(low = palette["accent2"],
                           high = palette["accent3"],
                           name = "|Residual|") +
      geom_smooth(method = "loess", color = palette["accent4"],
                  se = FALSE, linewidth = .8) +
      labs(x = "Fitted (°C)", y = "Residuals (°C)",
           title = sprintf("Residuals vs Fitted — %s", input$selected_city)) +
      theme_wx()

    ggplotly_wx(p)
  })

  # ---- Tab 3: Coefficients table ----
  output$coef_table_out <- renderDT({
    r_city_coefs() %>%
      select(Predictor = predictor, Estimate = estimate,
             `Std Error` = std_error, `t value` = t_value,
             `p-value` = p_value, Significant = significant) %>%
      datatable(
        options  = list(pageLength = 15, dom = "tp"),
        rownames = FALSE, class = "compact"
      ) %>%
      formatStyle(
        "Significant",
        backgroundColor = styleEqual(c(TRUE, FALSE),
                                     c("#3fb95022", "transparent")),
        color = styleEqual(c(TRUE, FALSE), c("#3fb950", "#8b949e"))
      ) %>%
      formatStyle(
        "p-value",
        color = styleInterval(c(0.001, 0.01, 0.05),
                              c("#3fb950","#58a6ff","#f78166","#8b949e"))
      )
  })

  # ---- Tab 4: Model ranking ----
  output$model_ranking_plot <- renderPlotly({
    d <- stats %>% arrange(r_squared) %>%
      mutate(city = factor(city, city))

    p <- ggplot(d) +
      geom_col(aes(x = r_squared, y = city, fill = r_squared),
               alpha = .85) +
      geom_text(aes(x = r_squared + .005, y = city,
                    label = sprintf("%.3f", r_squared)),
                color = palette["text"], size = 3, hjust = 0) +
      scale_fill_gradient(low  = palette["accent3"],
                          high = palette["accent2"],
                          guide = "none") +
      xlim(0, 1.05) +
      labs(x = "R² (coefficient of determination)", y = NULL,
           title = "Linear Regression Model Performance by City") +
      theme_wx()

    ggplotly_wx(p)
  })

  # ---- Tab 4: Model stats table ----
  output$model_stats_table <- renderDT({
    stats %>%
      arrange(desc(r_squared)) %>%
      datatable(
        options  = list(pageLength = 20, dom = "tp"),
        rownames = FALSE, class = "compact"
      ) %>%
      formatStyle("r_squared",
                  background = styleColorBar(c(0,1), palette["accent2"]),
                  backgroundSize = "100% 70%",
                  backgroundRepeat = "no-repeat",
                  backgroundPosition = "center")
  })

  # ---- Refresh button ----
  observeEvent(input$refresh_btn, {
    showNotification(
      "Re-running scraping and transformation scripts...",
      type = "message", duration = 4
    )
    # In production: source("01_data_scraping.R"); source("02_data_transformation.R")
    # then session$reload()
    showNotification(
      "To fully refresh: re-run 01_data_scraping.R → 02_data_transformation.R → restart app",
      type = "warning", duration = 8
    )
  })
}

shinyApp(ui, server)
