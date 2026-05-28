# 💼 Canada Jobs & Salaries Dashboard

An interactive data analysis and visualization dashboard exploring compensation trends, job market patterns, and salary drivers across roles, experience levels, and locations — with a focus on the Canadian tech and data science job market.

**[🚀 Live App](https://rafpk.shinyapps.io/jobs_project/)**

---

## Overview

This project answers a practical career question: *what actually drives salary in the data and tech job market?* Using real compensation data, it performs end-to-end EDA, statistical analysis, and interactive visualization to surface actionable insights for job seekers, hiring managers, and workforce analysts.

---

## Tech Stack

| Layer | Tools |
|-------|-------|
| Language | R |
| Web Framework | Shiny |
| Data Storage | SQL / SQLite |
| Data Wrangling | `dplyr`, `tidyr` |
| Visualization | `ggplot2`, `plotly` |
| Deployment | shinyapps.io |

---

## Data Pipeline

```
Raw Compensation Dataset
(ai-jobs.net + Job Bank Canada)
        │
        ▼
  Data Ingestion & Loading
        │
        ▼
  Data Cleaning & Validation
  ├── Missing value handling
  ├── Outlier detection & treatment
  ├── Field standardization
  └── Duplicate removal
        │
        ▼
  SQL Querying & Aggregation
  (SQLite for structured extraction)
        │
        ▼
  Exploratory Data Analysis (EDA)
  ├── Distribution analysis
  ├── YoY trend analysis
  ├── Segment comparisons
  └── Correlation analysis
        │
        ▼
  Shiny Dashboard (AI assistance)
  (interactive filters + visualizations)
```

---

## Analysis Performed

### Compensation Drivers
- Identified key variables driving salary variation: role category, experience level, company size, remote work status, and geography
- Applied statistical summarization to quantify the wage premium associated with each factor

### Trend Analysis
- Year-over-year salary trends across job categories
- Demand growth patterns by role type and location
- Emerging vs. declining role segments in the Canadian market

### Segmentation
- Salary distribution by experience level (entry / mid / senior / executive)
- Cross-geography comparison: Canada vs. US vs. global remote
- Role-level breakdowns: Data Scientist, Data Analyst, ML Engineer, Data Engineer

---

## Key Dashboard Features

- **Salary distribution explorer** — filter by role, experience, location, and company size
- **YoY trend charts** — track compensation changes over time by segment
- **Role comparison** — side-by-side salary benchmarking across job titles
- **Geography heatmap** — visualize compensation geography across regions
- **Pay disparity analysis** — identify gaps across experience levels and categories
- **Dynamic SQL filtering** — all views powered by live SQL queries against the underlying dataset

---

## Project Structure

```
jobs_project/
├── app.R              # Shiny app entry point
├── global.R           # Data loading, SQL connection, preprocessing
├── ui.R               # Dashboard UI layout and tab structure
├── server.R           # Reactive server logic and plot rendering
├── R/
│   ├── load_data.R    # Data ingestion and SQLite setup
│   ├── clean.R        # Data cleaning and validation pipeline
│   ├── analysis.R     # EDA functions and statistical summaries
│   └── plots.R        # ggplot2 and plotly visualization functions
├── data/
│   └── salaries.db    # SQLite database
└── README.md
```

---

## Running Locally

```r
# Install dependencies
install.packages(c("shiny", "DBI", "RSQLite", "dplyr", "tidyr",
                   "ggplot2", "plotly", "stringr", "scales"))

# Clone and run
shiny::runApp("jobs_project/")
```

---

## Skills Demonstrated

- SQL database design, querying, and aggregation (SQLite)
- ETL pipeline: raw data ingestion → cleaning → validation → analysis → reporting
- Exploratory data analysis (EDA) on real-world compensation data
- Statistical summarization and segment analysis
- Interactive dashboard design with dynamic filtering
- Data storytelling — translating analysis into business-relevant insights
- Production deployment on shinyapps.io
