# 🌦️ WeatherML Americas — Forecasting App

A production-grade weather forecasting web application built entirely in R, delivering live 24-hour predictions with confidence intervals across 20 cities in the Americas.

**[🚀 Live App](https://rafpk.shinyapps.io/weather_project/)**

---

## Overview

This project demonstrates an end-to-end data science pipeline — from real-time API ingestion through statistical modelling to interactive dashboard deployment. It solves a practical problem: providing interpretable, city-level weather forecasts with full model diagnostics surfaced in a clean, non-technical UI.

---

## Tech Stack

| Layer | Tools |
|-------|-------|
| Language | R |
| Web Framework | Shiny |
| Data Source | Open-Meteo REST API |
| Modelling | `lm()` — per-city linear regression |
| Visualization | `ggplot2`, `plotly` |
| Deployment | shinyapps.io |

---

## ETL Pipeline Architecture

```
Open-Meteo REST API
        │
        ▼
  API Ingestion (httr)
        │
        ▼
  Data Cleaning & Validation
        │
        ▼
  Feature Transformation
  (lag features, time encoding)
        │
        ▼
  Per-City Model Fitting (lm())
        │
        ▼
  Forecast Generation
  (24-hr ahead, 95% prediction intervals)
        │
        ▼
  Shiny Dashboard (reactive, live refresh)
```

---

## Key Features

- **20 cities** across North and South America monitored in real time
- **24-hour ahead forecasts** with 95% prediction intervals per city
- **Per-city regression models** — each city gets its own independently trained model
- **Model performance metrics** reported for every city: R², Adjusted R², RMSE, MAE
- **Residual diagnostic suite** — residuals vs. fitted, Q-Q plots, scale-location plots
- **Coefficient significance tables** surfaced directly in the dashboard
- **Cross-city performance rankings** — compare model accuracy across all 20 locations
- **Live data refresh** — pipeline re-ingests and re-fits on each session

---

## Model Details

- **Algorithm:** Ordinary least squares linear regression (`lm()`)
- **Features:** Lagged temperature, humidity, wind speed, time-of-day and seasonal encodings
- **Evaluation metrics:** R², Adjusted R², RMSE (Root Mean Squared Error), MAE (Mean Absolute Error)
- **Inference:** 95% prediction intervals via `predict(..., interval = "prediction")`
- **Validation:** Residual normality and homoscedasticity checked per city

---

## Project Structure

```
weather_project/
├── app.R               # Shiny app entry point
├── global.R            # Shared data ingestion & model fitting pipeline
├── ui.R                # Dashboard UI layout
├── server.R            # Reactive server logic
├── R/
│   ├── fetch_data.R    # Open-Meteo API ingestion module
│   ├── clean_data.R    # Preprocessing & feature engineering
│   ├── fit_models.R    # Per-city lm() training & evaluation
│   └── forecast.R      # Prediction interval generation
└── README.md
```

---

## Running Locally

```r
# Install dependencies
install.packages(c("shiny", "httr", "jsonlite", "ggplot2", "plotly", "dplyr", "tidyr"))

# Clone and run
shiny::runApp("weather_project/")
```

---

## Skills Demonstrated

- REST API integration and ETL pipeline development
- Feature engineering from time-series meteorological data
- Statistical modelling and model evaluation in R
- Reactive dashboard design with live data refresh
- Production deployment on shinyapps.io
- Modular code architecture across R scripts
