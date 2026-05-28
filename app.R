# =============================================================================
# Canada Data Science Job Market Dashboard  v3
#
# Data sources:
#  1. ai-jobs.net salary survey (CC0 public domain) — weekly-updated CSV on GitHub
#     https://github.com/foorilla/ai-jobs-net-salaries
#  2. Government of Canada Job Bank — live wage scrape via rvest (no API key needed)
#     https://www.jobbank.gc.ca/wagereport/occupation/<id>
# =============================================================================

library(shiny)
library(bslib)
library(dplyr)
library(tidyr)
library(ggplot2)
library(plotly)
library(DT)
library(scales)
library(rvest)
library(httr)

# ── Constants ─────────────────────────────────────────────────────────────────

# ai-jobs.net CC0 salary CSV — stable raw GitHub URL, updated every week
AIJOBS_CSV_URL <- "https://raw.githubusercontent.com/foorilla/ai-jobs-net-salaries/main/salaries.csv"

# Job Bank NOC occupation IDs for live wage scraping
JOB_BANK_IDS <- c(
  "Data Scientist"            = "227147",
  "Software Developer"        = "225188",
  "Database Analyst / DBA"    = "225185",
  "Business Systems Analyst"  = "225183",
  "Cybersecurity Specialist"  = "568059",
  "ML / AI Engineer"          = "568231",
  "Data Engineer"             = "568229",
  "Cloud Architect"           = "225186",
  "IT Manager"                = "14514"
)

JOB_BANK_BASE <- "https://www.jobbank.gc.ca/wagereport/occupation/"

# Profession name → ai-jobs title patterns (for matching the survey data)
TITLE_MAP <- list(
  "Data Scientist"           = c("data scientist", "data science"),
  "Software Developer"       = c("software engineer", "software developer", "backend", "frontend", "full stack"),
  "Database Analyst / DBA"   = c("database", "dba", "data administrator"),
  "Business Systems Analyst" = c("business analyst", "systems analyst", "bi analyst"),
  "Cybersecurity Specialist" = c("security engineer", "cybersecurity", "information security"),
  "ML / AI Engineer"         = c("machine learning", "ml engineer", "ai engineer", "mlops"),
  "Data Engineer"            = c("data engineer", "etl", "data platform"),
  "Cloud Architect"          = c("cloud", "devops", "platform engineer", "site reliability"),
  "IT Manager"               = c("engineering manager", "it manager", "tech lead", "director of engineering")
)

# CAD/USD exchange rate approximation (2024 average)
USD_TO_CAD <- 1.36

# ── Data fetching ─────────────────────────────────────────────────────────────

fetch_aijobs <- function() {
  tryCatch({
    df <- read.csv(url(AIJOBS_CSV_URL), stringsAsFactors = FALSE)
    # Columns: work_year, experience_level, employment_type, job_title,
    #          salary, salary_currency, salary_in_usd, employee_residence,
    #          remote_ratio, company_location, company_size
    df <- df %>%
      mutate(
        salary_cad = salary_in_usd * USD_TO_CAD,
        experience_label = recode(experience_level,
          "EN" = "Entry",
          "MI" = "Mid",
          "SE" = "Senior",
          "EX" = "Executive"
        ),
        # Assign our standard profession buckets
        profession = {
          jt <- tolower(job_title)
          result <- rep(NA_character_, length(jt))
          for (prof in names(TITLE_MAP)) {
            patterns <- TITLE_MAP[[prof]]
            matched <- Reduce(`|`, lapply(patterns, function(p) grepl(p, jt, fixed = TRUE)))
            result[is.na(result) & matched] <- prof
          }
          result
        }
      ) %>%
      filter(!is.na(profession), salary_cad > 20000, salary_cad < 800000)
    df
  }, error = function(e) {
    message("ai-jobs fetch failed: ", e$message)
    NULL
  })
}

scrape_jobbank_wage <- function(occ_id, occ_name) {
  tryCatch({
    url_str <- paste0(JOB_BANK_BASE, occ_id)
    page <- read_html(GET(url_str,
                          user_agent("Mozilla/5.0 (compatible; R/shiny)"),
                          timeout(15)))

    # Job Bank wage table: Low / Median / High wages
    wage_nodes <- page %>%
      html_elements("td.wages-value, .wage-data td, table.table td") %>%
      html_text(trim = TRUE)

    # Extract dollar amounts like $32.00 or $38.50
    dollar_vals <- regmatches(wage_nodes,
                              gregexpr("\\$[0-9]+\\.?[0-9]*", wage_nodes))
    dollar_vals <- unlist(dollar_vals)
    dollar_vals <- as.numeric(gsub("\\$", "", dollar_vals))
    dollar_vals <- dollar_vals[dollar_vals > 10 & dollar_vals < 300]

    if (length(dollar_vals) < 2) return(NULL)

    # Sort so we reliably get low / median / high
    dollar_vals <- sort(dollar_vals)
    n <- length(dollar_vals)
    tibble(
      profession   = occ_name,
      hourly_low    = dollar_vals[1],
      hourly_median = dollar_vals[ceiling(n / 2)],
      hourly_high   = dollar_vals[n],
      annual_low    = dollar_vals[1]                * 2080,
      annual_median = dollar_vals[ceiling(n / 2)]   * 2080,
      annual_high   = dollar_vals[n]                * 2080,
      source        = "Job Bank Canada (live)"
    )
  }, error = function(e) {
    message(sprintf("Job Bank scrape failed for %s: %s", occ_name, e$message))
    NULL
  })
}

scrape_all_jobbank <- function() {
  rows <- lapply(names(JOB_BANK_IDS), function(name) {
    scrape_jobbank_wage(JOB_BANK_IDS[[name]], name)
  })
  result <- bind_rows(Filter(Negate(is.null), rows))
  if (nrow(result) == 0) return(NULL)
  result
}

# ── Load on startup ───────────────────────────────────────────────────────────
aijobs_data  <- fetch_aijobs()
jobbank_data <- scrape_all_jobbank()

# Profession list comes from whichever source has data
professions_list <- if (!is.null(aijobs_data)) {
  sort(unique(aijobs_data$profession))
} else {
  names(JOB_BANK_IDS)
}

years_list <- if (!is.null(aijobs_data)) {
  sort(unique(aijobs_data$work_year), decreasing = TRUE)
} else {
  as.integer(format(Sys.Date(), "%Y"))
}

# ── Helpers ───────────────────────────────────────────────────────────────────
fmt_cad <- function(x) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) return("N/A")
  dollar(mean(x, na.rm = TRUE), prefix = "CA$", big.mark = ",", accuracy = 1)
}

PALETTE <- c("#3a86ff","#8338ec","#ff6b6b","#ffd166","#06d6a0",
             "#ef476f","#118ab2","#f77f00","#a8dadc")

# ── UI ────────────────────────────────────────────────────────────────────────
ui <- fluidPage(
  theme = bs_theme(
    version      = 5,
    bg           = "#0d1117",
    fg           = "#e6edf3",
    primary      = "#3a86ff",
    secondary    = "#8338ec",
    base_font    = font_google("JetBrains Mono"),
    heading_font = font_google("Outfit")
  ),

  tags$head(tags$title("Canada DS Jobs")),
  tags$style(HTML("
    body { background:#0d1117; }
    .card { background:#161b22; border:1px solid #30363d; border-radius:12px; padding:24px; margin-bottom:20px; }
    .stat-grid { display:grid; grid-template-columns:repeat(5,1fr); gap:14px; }
    .stat-box  { background:#161b22; border:1px solid #30363d; border-radius:10px;
                 padding:18px 14px; text-align:center; transition:.15s; }
    .stat-box:hover { border-color:#3a86ff; transform:translateY(-2px); box-shadow:0 4px 20px #3a86ff22; }
    .stat-lbl  { font-size:10px; text-transform:uppercase; letter-spacing:2px; color:#7d8590; margin-bottom:6px; }
    .stat-val  { font-size:24px; font-weight:700; color:#3a86ff; }
    .stat-sub  { font-size:11px; color:#7d8590; margin-top:4px; }
    .section-title { font-size:10px; text-transform:uppercase; letter-spacing:3px;
                     color:#3a86ff; margin-bottom:16px; font-family:'JetBrains Mono',monospace; }
    .badge-pill { display:inline-block; background:#1f2d3d; color:#3a86ff; border-radius:20px;
                  padding:4px 14px; font-size:11px; letter-spacing:1px; margin-bottom:18px; }
    .nav-tabs .nav-link { font-size:12px; letter-spacing:1px; color:#7d8590 !important; }
    .nav-tabs .nav-link.active { color:#3a86ff !important; border-color:#3a86ff !important; background:transparent !important; }
    select, .form-select, .selectize-input { background:#161b22 !important; border-color:#30363d !important;
      color:#e6edf3 !important; border-radius:8px !important; }
    .btn-primary { background:#3a86ff; border:none; border-radius:8px; font-size:12px; letter-spacing:1px; }
    .jb-card { background:linear-gradient(135deg,#1a2332,#161b22); border:1px solid #3a86ff33;
               border-radius:12px; padding:20px; }
    hr { border-color:#30363d; }
    .data-note { font-size:11px; color:#7d8590; margin-top:8px; }
  ")),

  # Header
  div(style="padding:28px 36px 8px;",
    h2(style="margin:0; background:linear-gradient(90deg,#3a86ff,#8338ec);
              -webkit-background-clip:text; -webkit-text-fill-color:transparent; font-weight:800;",
       "🇨🇦 Canada Data Science Job Market"),
    div(class="badge-pill", "📡 Live  ·  ai-jobs.net survey (CC0)  +  Job Bank Canada scrape"),
    tags$small(style="color:#7d8590; display:block; margin-top:-8px; margin-bottom:16px;",
      paste("Data loaded:", format(Sys.time(), "%b %d %Y %H:%M"), "·",
            if (!is.null(aijobs_data)) paste(nrow(aijobs_data), "global salary records") else "ai-jobs offline",
            "·",
            if (!is.null(jobbank_data)) paste(nrow(jobbank_data), "Job Bank wages scraped") else "Job Bank offline"))
  ),

  div(style="padding:0 36px 40px;",
    navset_tab(
      id = "tabs",

      # ── TAB 1: Summary Stats ─────────────────────────────────────────────
      nav_panel("📊 Summary Stats",
        br(),
        fluidRow(
          column(4,
            tags$label(class="section-title", "Profession"),
            selectInput("s_prof", NULL, choices=professions_list, width="100%")
          ),
          column(3,
            tags$label(class="section-title", "Experience Level"),
            selectInput("s_exp", NULL,
                        choices=c("All"="all","Entry"="Entry","Mid"="Mid",
                                  "Senior"="Senior","Executive"="Executive"),
                        width="100%")
          ),
          column(3,
            tags$label(class="section-title", "Source"),
            selectInput("s_source", NULL,
                        choices=c("ai-jobs.net (global survey)"="aijobs",
                                  "Job Bank Canada (scraped)"="jobbank"),
                        width="100%")
          ),
          column(2, br(),
            actionButton("btn_refresh", "🔄 Refresh", class="btn btn-primary w-100")
          )
        ),
        br(),
        # 5-number summary cards
        div(class="section-title", "Five-Number Summary  ·  Annual Salary (CAD)"),
        div(class="stat-grid",
          div(class="stat-box", div(class="stat-lbl","Minimum"),
              div(class="stat-val", textOutput("st_min",inline=TRUE)),
              div(class="stat-sub","Low band")),
          div(class="stat-box", div(class="stat-lbl","Q1 (25th pct)"),
              div(class="stat-val", textOutput("st_q1",inline=TRUE)),
              div(class="stat-sub","Lower quartile")),
          div(class="stat-box", div(class="stat-lbl","Median"),
              div(class="stat-val", textOutput("st_med",inline=TRUE)),
              div(class="stat-sub","50th percentile")),
          div(class="stat-box", div(class="stat-lbl","Mean"),
              div(class="stat-val", textOutput("st_mean",inline=TRUE)),
              div(class="stat-sub","Average salary")),
          div(class="stat-box", div(class="stat-lbl","Maximum"),
              div(class="stat-val", textOutput("st_max",inline=TRUE)),
              div(class="stat-sub","High band"))
        ),
        br(),
        fluidRow(
          column(8,
            div(class="card",
              div(class="section-title","All Professions — Salary Distribution"),
              plotlyOutput("bar_profs", height="420px")
            )
          ),
          column(4,
            div(class="jb-card",
              div(class="section-title","🏦 Job Bank Canada — Live Wages"),
              uiOutput("jobbank_panel")
            )
          )
        ),
        div(class="card",
          div(class="section-title","Full Data Table"),
          DTOutput("data_table")
        )
      ),

      # ── TAB 2: Salary vs Year ────────────────────────────────────────────
      nav_panel("📈 Salary vs Year",
        br(),
        fluidRow(
          column(5,
            tags$label(class="section-title","Professions"),
            selectInput("t_profs", NULL, choices=professions_list,
                        multiple=TRUE,
                        selected=head(professions_list, 3), width="100%")
          ),
          column(4,
            tags$label(class="section-title","Salary Metric"),
            selectInput("t_metric", NULL,
                        choices=c("Median"="median","Mean"="mean",
                                  "75th Pct"="p75","25th Pct"="p25"),
                        width="100%")
          ),
          column(3,
            tags$label(class="section-title","Chart Style"),
            selectInput("t_style", NULL,
                        choices=c("Line + Points"="line","Area"="area","Bar"="bar"),
                        width="100%")
          )
        ),
        br(),
        div(class="card",
          div(class="section-title","Annual Salary Trend by Year"),
          plotlyOutput("trend_plot", height="460px")
        ),
        div(class="card",
          div(class="section-title","Year-over-Year Growth (%)"),
          plotlyOutput("yoy_plot", height="260px")
        )
      ),

      # ── TAB 3: Compare ───────────────────────────────────────────────────
      nav_panel("⚖️ Compare",
        br(),
        fluidRow(
          column(5,
            tags$label(class="section-title","Profession A"),
            selectInput("c_a", NULL, choices=professions_list,
                        selected=professions_list[1], width="100%")
          ),
          column(2,
            div(style="text-align:center;padding-top:30px;font-size:22px;color:#7d8590;","vs")
          ),
          column(5,
            tags$label(class="section-title","Profession B"),
            selectInput("c_b", NULL, choices=professions_list,
                        selected=professions_list[min(2,length(professions_list))],
                        width="100%")
          )
        ),
        br(),
        fluidRow(
          column(6,
            div(class="card",
              div(class="section-title","Salary Range (Low / Median / High)"),
              plotlyOutput("cmp_range", height="360px")
            )
          ),
          column(6,
            div(class="card",
              div(class="section-title","Trend Over Years"),
              plotlyOutput("cmp_trend", height="360px")
            )
          )
        ),
        div(class="card",
          div(class="section-title","Side-by-Side Stats"),
          DTOutput("cmp_table")
        )
      ),

      # ── TAB 4: Forecast ──────────────────────────────────────────────────
      nav_panel("🔮 Forecast",
        br(),
        fluidRow(
          column(5,
            tags$label(class="section-title","Profession"),
            selectInput("f_prof", NULL, choices=professions_list,
                        selected=professions_list[1], width="100%")
          ),
          column(4,
            tags$label(class="section-title","Forecast Horizon"),
            sliderInput("f_horizon", NULL, min=1, max=5, value=3, step=1, width="100%")
          ),
          column(3,
            tags$label(class="section-title","Model"),
            selectInput("f_method", NULL,
                        choices=c("Linear Trend"="lm",
                                  "Holt-Winters"="hw",
                                  "CAGR (salary-based)"="cagr"),
                        width="100%")
          )
        ),
        br(),
        fluidRow(
          column(4,
            div(class="jb-card",
              div(class="section-title","Projected New Positions"),
              uiOutput("forecast_cards")
            )
          ),
          column(8,
            div(class="card",
              div(class="section-title","New Job Openings Forecast"),
              plotlyOutput("forecast_plot", height="380px")
            )
          )
        ),
        br(),
        div(class="card",
          div(class="section-title","ℹ Methodology"),
          p(class="data-note",
            "Historical counts = number of salary survey respondents per year × 500 (national scale proxy). ",
            "Models: Linear OLS, Holt-Winters exponential smoothing, or 2× salary CAGR projection. ",
            "90% prediction interval shown as shaded band. These are statistical estimates, not official projections.")
        )
      ),

      # ── TAB 5: About ─────────────────────────────────────────────────────
      nav_panel("ℹ About",
        br(),
        div(class="card", style="max-width:760px;",
          h4(style="color:#3a86ff;","Data Sources"),
          tags$ul(
            tags$li(strong("ai-jobs.net Salary Survey (CC0 Public Domain):"),
              " Weekly-updated CSV of global AI/ML/Data Science salaries. ",
              tags$a("github.com/foorilla/ai-jobs-net-salaries",
                     href="https://github.com/foorilla/ai-jobs-net-salaries",
                     target="_blank", style="color:#8338ec;")),
            tags$li(strong("Government of Canada — Job Bank:"),
              " Live wage data scraped by NOC occupation. ",
              tags$a("jobbank.gc.ca", href="https://www.jobbank.gc.ca",
                     target="_blank", style="color:#8338ec;"))
          ),
          hr(),
          h4(style="color:#3a86ff;","Salary Conversion"),
          p("ai-jobs.net figures are in USD and converted to CAD at the 2024 annual average rate of 1 USD = 1.36 CAD.",
            class="data-note"),
          hr(),
          h4(style="color:#3a86ff;","Experience Levels"),
          tags$ul(class="data-note",
            tags$li("EN — Entry level / Junior"),
            tags$li("MI — Mid level"),
            tags$li("SE — Senior level"),
            tags$li("EX — Executive / Director / Principal")
          ),
          hr(),
          p(class="data-note",
            "Built with R · Shiny · ggplot2 · plotly · rvest · bslib  |  ",
            "ai-jobs.net data © CC0 Public Domain")
        )
      )
    )
  )
)

# ── Server ────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {

  # Reactive data stores (refreshable)
  rv_aijobs  <- reactiveVal(aijobs_data)
  rv_jobbank <- reactiveVal(jobbank_data)

  observeEvent(input$btn_refresh, {
    showNotification("Fetching latest data…", type="message", duration=3)
    rv_aijobs(fetch_aijobs())
    rv_jobbank(scrape_all_jobbank())
    showNotification("✅ Data refreshed!", type="message", duration=3)
  })

  # ── Filtered reactive for summary tab ──────────────────────────────────────
  summary_df <- reactive({
    df <- rv_aijobs()
    if (is.null(df)) return(NULL)
    df <- df %>% filter(profession == input$s_prof)
    if (input$s_exp != "all") df <- df %>% filter(experience_label == input$s_exp)
    df
  })

  # ── 5-number summary (from ai-jobs OR jobbank depending on s_source) ───────
  summary_vals <- reactive({
    if (input$s_source == "aijobs") {
      df <- summary_df()
      if (is.null(df) || nrow(df) == 0) return(NULL)
      v <- df$salary_cad
      list(min  = quantile(v, 0.0,  na.rm=TRUE),
           q1   = quantile(v, 0.25, na.rm=TRUE),
           med  = median(v, na.rm=TRUE),
           mean = mean(v, na.rm=TRUE),
           max  = quantile(v, 1.0,  na.rm=TRUE))
    } else {
      jb <- rv_jobbank()
      if (is.null(jb)) return(NULL)
      row <- jb %>% filter(profession == input$s_prof)
      if (nrow(row) == 0) return(NULL)
      med <- row$annual_median[1]
      low <- row$annual_low[1]
      hi  <- row$annual_high[1]
      list(min  = low,
           q1   = (low + med) / 2,
           med  = med,
           mean = med,
           max  = hi)
    }
  })

  output$st_min  <- renderText({ sv <- summary_vals(); if(is.null(sv)) "N/A" else fmt_cad(sv$min)  })
  output$st_q1   <- renderText({ sv <- summary_vals(); if(is.null(sv)) "N/A" else fmt_cad(sv$q1)   })
  output$st_med  <- renderText({ sv <- summary_vals(); if(is.null(sv)) "N/A" else fmt_cad(sv$med)  })
  output$st_mean <- renderText({ sv <- summary_vals(); if(is.null(sv)) "N/A" else fmt_cad(sv$mean) })
  output$st_max  <- renderText({ sv <- summary_vals(); if(is.null(sv)) "N/A" else fmt_cad(sv$max)  })

  # ── Bar chart — all professions ────────────────────────────────────────────
  output$bar_profs <- renderPlotly({
    df <- rv_aijobs()
    if (is.null(df)) return(NULL)

    df_plot <- df %>%
      group_by(profession) %>%
      summarise(
        median_sal = median(salary_cad, na.rm=TRUE),
        q1         = quantile(salary_cad, 0.25, na.rm=TRUE),
        q3         = quantile(salary_cad, 0.75, na.rm=TRUE),
        n          = n(),
        .groups    = "drop"
      ) %>%
      arrange(median_sal) %>%
      mutate(profession = factor(profession, levels=profession))

    plot_ly(df_plot, y=~profession, x=~median_sal,
            type="bar", orientation="h",
            marker=list(color="#3a86ff", opacity=0.85),
            name="Median") %>%
      add_segments(x=~q1, xend=~q3, y=~profession, yend=~profession,
                   line=list(color="#8338ec", width=4),
                   name="IQR (25–75th pct)") %>%
      layout(
        paper_bgcolor="transparent", plot_bgcolor="transparent",
        font=list(color="#e6edf3", family="JetBrains Mono"),
        xaxis=list(title="Annual Salary (CAD)", gridcolor="#30363d",
                   tickformat="$,.0f"),
        yaxis=list(title="", gridcolor="#30363d"),
        legend=list(font=list(color="#7d8590")),
        margin=list(l=10)
      )
  })

  # ── Job Bank live wages panel ──────────────────────────────────────────────
  output$jobbank_panel <- renderUI({
    jb <- rv_jobbank()
    if (is.null(jb) || nrow(jb) == 0) {
      return(div(class="data-note",
                 "⚠ Job Bank data unavailable. Click Refresh to retry."))
    }
    row <- jb %>% filter(profession == input$s_prof)
    if (nrow(row) == 0) {
      return(div(class="data-note",
                 paste("No Job Bank data for", input$s_prof)))
    }
    tagList(
      div(style="margin-bottom:14px;",
        div(class="stat-lbl","Hourly Low"),
        div(style="font-size:20px;font-weight:700;color:#06d6a0;",
            sprintf("$%.2f/hr", row$hourly_low[1])),
        div(class="stat-sub", sprintf("≈ %s/yr", fmt_cad(row$annual_low[1])))
      ),
      div(style="margin-bottom:14px;",
        div(class="stat-lbl","Hourly Median"),
        div(style="font-size:20px;font-weight:700;color:#3a86ff;",
            sprintf("$%.2f/hr", row$hourly_median[1])),
        div(class="stat-sub", sprintf("≈ %s/yr", fmt_cad(row$annual_median[1])))
      ),
      div(
        div(class="stat-lbl","Hourly High"),
        div(style="font-size:20px;font-weight:700;color:#8338ec;",
            sprintf("$%.2f/hr", row$hourly_high[1])),
        div(class="stat-sub", sprintf("≈ %s/yr", fmt_cad(row$annual_high[1])))
      ),
      tags$hr(),
      div(class="data-note",
          "Live from jobbank.gc.ca · Hourly × 2,080 = Annual")
    )
  })

  # ── Full data table ────────────────────────────────────────────────────────
  output$data_table <- renderDT({
    df <- rv_aijobs()
    if (is.null(df)) return(NULL)
    df %>%
      select(Year=work_year, Profession=profession, Title=job_title,
             Experience=experience_label, `Salary (CAD)`=salary_cad,
             Country=company_location) %>%
      mutate(`Salary (CAD)` = dollar(`Salary (CAD)`, prefix="CA$", accuracy=1)) %>%
      arrange(desc(Year)) %>%
      datatable(
        options=list(pageLength=12, dom="ftp", scrollX=TRUE,
          initComplete=JS("function(s,d,n){
            $(n[0]).css({'background':'#161b22','color':'#e6edf3'});
          }")),
        class="compact hover", rownames=FALSE, style="bootstrap5"
      )
  })

  # ── Trend tab ─────────────────────────────────────────────────────────────
  trend_df <- reactive({
    df <- rv_aijobs()
    if (is.null(df) || length(input$t_profs) == 0) return(NULL)

    df %>%
      filter(profession %in% input$t_profs) %>%
      group_by(profession, work_year) %>%
      summarise(
        median = median(salary_cad, na.rm=TRUE),
        mean   = mean(salary_cad,   na.rm=TRUE),
        p25    = quantile(salary_cad, 0.25, na.rm=TRUE),
        p75    = quantile(salary_cad, 0.75, na.rm=TRUE),
        .groups = "drop"
      )
  })

  output$trend_plot <- renderPlotly({
    df <- trend_df()
    if (is.null(df)) return(NULL)
    metric <- input$t_metric
    p <- plot_ly()
    for (i in seq_along(unique(df$profession))) {
      prof <- unique(df$profession)[i]
      col  <- PALETTE[(i-1) %% length(PALETTE) + 1]
      sub  <- df %>% filter(profession == prof)
      if (input$t_style == "line") {
        p <- p %>% add_trace(data=sub, x=~work_year, y=~.data[[metric]],
                             type="scatter", mode="lines+markers", name=prof,
                             line=list(color=col,width=2.5),
                             marker=list(color=col,size=8))
      } else if (input$t_style == "area") {
        p <- p %>% add_trace(data=sub, x=~work_year, y=~.data[[metric]],
                             type="scatter", mode="lines", fill="tozeroy",
                             fillcolor=paste0(col,"28"), line=list(color=col,width=2),
                             name=prof)
      } else {
        p <- p %>% add_bars(data=sub, x=~work_year, y=~.data[[metric]],
                            name=prof, marker=list(color=col,opacity=0.8))
      }
    }
    p %>% layout(
      paper_bgcolor="transparent", plot_bgcolor="transparent",
      font=list(color="#e6edf3", family="JetBrains Mono"),
      xaxis=list(title="Year", gridcolor="#30363d", dtick=1),
      yaxis=list(title="Annual Salary (CAD)", gridcolor="#30363d", tickformat="$,.0f"),
      legend=list(font=list(color="#7d8590")),
      barmode="group"
    )
  })

  output$yoy_plot <- renderPlotly({
    df <- trend_df()
    if (is.null(df)) return(NULL)
    metric <- input$t_metric
    df_g <- df %>%
      arrange(profession, work_year) %>%
      group_by(profession) %>%
      mutate(yoy = (.data[[metric]] / lag(.data[[metric]]) - 1) * 100) %>%
      filter(!is.na(yoy))

    p <- plot_ly()
    for (i in seq_along(unique(df_g$profession))) {
      prof <- unique(df_g$profession)[i]
      col  <- PALETTE[(i-1) %% length(PALETTE) + 1]
      sub  <- df_g %>% filter(profession == prof)
      p <- p %>% add_bars(data=sub, x=~work_year, y=~yoy, name=prof,
                          marker=list(color=col, opacity=0.8))
    }
    p %>% layout(
      paper_bgcolor="transparent", plot_bgcolor="transparent",
      font=list(color="#e6edf3", family="JetBrains Mono"),
      xaxis=list(title="Year", gridcolor="#30363d", dtick=1),
      yaxis=list(title="YoY Growth (%)", gridcolor="#30363d", ticksuffix="%"),
      barmode="group",
      legend=list(font=list(color="#7d8590")),
      shapes=list(list(type="line", x0=0,x1=1, xref="paper",
                       y0=0, y1=0, line=list(color="#7d8590",dash="dot")))
    )
  })

  # ── Compare tab ────────────────────────────────────────────────────────────
  output$cmp_range <- renderPlotly({
    df <- rv_aijobs()
    jb <- rv_jobbank()
    if (is.null(df)) return(NULL)
    profs <- c(input$c_a, input$c_b)
    df_c <- df %>%
      filter(profession %in% profs) %>%
      group_by(profession) %>%
      summarise(low=quantile(salary_cad,.1,na.rm=TRUE),
                med=median(salary_cad,na.rm=TRUE),
                high=quantile(salary_cad,.9,na.rm=TRUE),.groups="drop")

    cols <- c("#3a86ff","#8338ec")
    p <- plot_ly()
    for (i in 1:nrow(df_c)) {
      p <- p %>% add_trace(
        x=c(df_c$low[i], df_c$med[i], df_c$high[i]),
        y=c(df_c$profession[i], df_c$profession[i], df_c$profession[i]),
        type="scatter", mode="markers+lines", name=df_c$profession[i],
        line=list(color=cols[min(i,2)],width=5),
        marker=list(color=cols[min(i,2)],size=c(10,16,10),
                    symbol=c("circle","diamond","circle"))
      )
    }
    p %>% layout(
      paper_bgcolor="transparent", plot_bgcolor="transparent",
      font=list(color="#e6edf3", family="JetBrains Mono"),
      xaxis=list(title="Annual Salary (CAD)", gridcolor="#30363d", tickformat="$,.0f"),
      yaxis=list(title="", gridcolor="#30363d"),
      legend=list(font=list(color="#7d8590"))
    )
  })

  output$cmp_trend <- renderPlotly({
    df <- rv_aijobs()
    if (is.null(df)) return(NULL)
    profs <- c(input$c_a, input$c_b)
    df_t <- df %>%
      filter(profession %in% profs) %>%
      group_by(profession, work_year) %>%
      summarise(med=median(salary_cad,na.rm=TRUE),.groups="drop")

    cols <- c("#3a86ff","#8338ec")
    p <- plot_ly()
    for (i in seq_along(unique(df_t$profession))) {
      prof <- unique(df_t$profession)[i]
      sub  <- df_t %>% filter(profession==prof)
      p <- p %>% add_trace(data=sub, x=~work_year, y=~med,
                           type="scatter", mode="lines+markers", name=prof,
                           line=list(color=cols[min(i,2)],width=2.5),
                           marker=list(color=cols[min(i,2)],size=8))
    }
    p %>% layout(
      paper_bgcolor="transparent", plot_bgcolor="transparent",
      font=list(color="#e6edf3", family="JetBrains Mono"),
      xaxis=list(title="Year", gridcolor="#30363d", dtick=1),
      yaxis=list(title="Median Salary (CAD)", gridcolor="#30363d", tickformat="$,.0f"),
      legend=list(font=list(color="#7d8590"))
    )
  })

  output$cmp_table <- renderDT({
    df <- rv_aijobs()
    if (is.null(df)) return(NULL)
    profs <- c(input$c_a, input$c_b)
    df %>%
      filter(profession %in% profs) %>%
      group_by(Profession=profession) %>%
      summarise(
        `Min (CA$)`    = dollar(quantile(salary_cad,.0, na.rm=TRUE), prefix="CA$",accuracy=1),
        `Q1 (CA$)`     = dollar(quantile(salary_cad,.25,na.rm=TRUE), prefix="CA$",accuracy=1),
        `Median (CA$)` = dollar(median(salary_cad,na.rm=TRUE),       prefix="CA$",accuracy=1),
        `Mean (CA$)`   = dollar(mean(salary_cad,na.rm=TRUE),         prefix="CA$",accuracy=1),
        `Max (CA$)`    = dollar(quantile(salary_cad,1.0,na.rm=TRUE), prefix="CA$",accuracy=1),
        `N`            = n(),
        .groups="drop"
      ) %>%
      datatable(options=list(dom="t",pageLength=5),
                class="compact", rownames=FALSE, style="bootstrap5")
  })

  # ── Forecast tab ───────────────────────────────────────────────────────────
  forecast_res <- reactive({
    df <- rv_aijobs()
    if (is.null(df)) return(NULL)

    hist <- df %>%
      filter(profession == input$f_prof) %>%
      group_by(work_year) %>%
      summarise(n=n(), med_sal=median(salary_cad,na.rm=TRUE), .groups="drop") %>%
      arrange(work_year) %>%
      mutate(openings = n * 500L)  # scale proxy

    if (nrow(hist) < 2) return(NULL)

    hz     <- input$f_horizon
    last_y <- max(hist$work_year)
    fut_y  <- seq(last_y+1, last_y+hz)

    sal_cagr <- tryCatch(
      (hist$med_sal[nrow(hist)]/hist$med_sal[1])^(1/(nrow(hist)-1))-1,
      error=function(e) 0.04
    )

    proj <- switch(input$f_method,
      lm = {
        mod <- lm(openings ~ work_year, data=hist)
        p   <- predict(mod, newdata=data.frame(work_year=fut_y),
                       interval="prediction", level=0.90)
        tibble(year=fut_y, point=pmax(p[,"fit"],0),
               lower=pmax(p[,"lwr"],0), upper=pmax(p[,"upr"],0))
      },
      hw = {
        if (nrow(hist)>=3) {
          ts_obj <- ts(hist$openings, start=min(hist$work_year))
          hw     <- HoltWinters(ts_obj, gamma=FALSE)
          p      <- predict(hw, n.ahead=hz, prediction.interval=TRUE, level=0.90)
          tibble(year=fut_y, point=pmax(as.numeric(p[,"fit"]),0),
                 lower=pmax(as.numeric(p[,"lwr"]),0),
                 upper=pmax(as.numeric(p[,"upr"]),0))
        } else {
          mod <- lm(openings ~ work_year, data=hist)
          p   <- predict(mod, newdata=data.frame(work_year=fut_y),
                         interval="prediction", level=0.90)
          tibble(year=fut_y, point=pmax(p[,"fit"],0),
                 lower=pmax(p[,"lwr"],0), upper=pmax(p[,"upr"],0))
        }
      },
      cagr = {
        g    <- sal_cagr * 2
        base <- tail(hist$openings, 1)
        tibble(year  = fut_y,
               point = base*(1+g)^seq_along(fut_y),
               lower = base*(1+g*.5)^seq_along(fut_y),
               upper = base*(1+g*1.5)^seq_along(fut_y))
      }
    )

    list(hist=hist, proj=proj, cagr=sal_cagr)
  })

  output$forecast_cards <- renderUI({
    res <- forecast_res()
    if (is.null(res)) return(p(class="data-note","Insufficient data for forecast."))
    cards <- lapply(1:nrow(res$proj), function(i) {
      div(style="margin-bottom:14px;",
        div(class="stat-lbl", paste("Year", res$proj$year[i])),
        div(style="font-size:22px;font-weight:700;color:#3a86ff;",
            formatC(round(res$proj$point[i]), format="d", big.mark=",")),
        div(class="stat-sub",
            sprintf("Range: %s – %s",
                    formatC(round(res$proj$lower[i]),format="d",big.mark=","),
                    formatC(round(res$proj$upper[i]),format="d",big.mark=",")))
      )
    })
    tagList(
      div(class="stat-lbl", sprintf("Salary CAGR: %.1f%%", res$cagr*100)),
      br(),
      tagList(cards)
    )
  })

  output$forecast_plot <- renderPlotly({
    res <- forecast_res()
    if (is.null(res)) return(NULL)

    plot_ly() %>%
      add_trace(data=res$hist, x=~work_year, y=~openings,
                type="scatter", mode="lines+markers", name="Historical",
                line=list(color="#3a86ff",width=2.5),
                marker=list(color="#3a86ff",size=8)) %>%
      add_ribbons(data=res$proj, x=~year, ymin=~lower, ymax=~upper,
                  fillcolor="rgba(131,56,236,0.2)",
                  line=list(color="transparent"), name="90% CI") %>%
      add_trace(data=res$proj, x=~year, y=~point,
                type="scatter", mode="lines+markers", name="Forecast",
                line=list(color="#8338ec",width=2.5,dash="dash"),
                marker=list(color="#8338ec",size=8,symbol="diamond")) %>%
      layout(
        paper_bgcolor="transparent", plot_bgcolor="transparent",
        font=list(color="#e6edf3", family="JetBrains Mono"),
        xaxis=list(title="Year", gridcolor="#30363d", dtick=1),
        yaxis=list(title="Est. New Positions", gridcolor="#30363d", tickformat=",d"),
        legend=list(font=list(color="#7d8590")),
        shapes=list(list(type="line",
                         x0=max(res$hist$work_year), x1=max(res$hist$work_year),
                         xref="x", y0=0, y1=1, yref="paper",
                         line=list(color="#7d8590",dash="dot",width=1)))
      )
  })
}

shinyApp(ui, server)
