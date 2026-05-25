🌦️ WeatherML Americas — Forecasting App
A production-grade weather forecasting web application built entirely in R, delivering live 24-hour predictions with confidence intervals across 20 cities in the Americas.
🚀 Live App

Overview
This project demonstrates an end-to-end data science pipeline — from real-time API ingestion through statistical modelling to interactive dashboard deployment. It solves a practical problem: providing interpretable, city-level weather forecasts with full model diagnostics surfaced in a clean, non-technical UI.
Tech Stack
LayerToolsLanguageRWeb FrameworkShinyData SourceOpen-Meteo REST APIModellinglm() — per-city linear regressionVisualizationggplot2, plotlyDeploymentshinyapps.io

ETL Pipeline Architecture
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

Key Features

20 cities across North and South America monitored in real time
24-hour ahead forecasts with 95% prediction intervals per city
Per-city regression models — each city gets its own independently trained model
Model performance metrics reported for every city: R², Adjusted R², RMSE, MAE
Residual diagnostic suite — residuals vs. fitted, Q-Q plots, scale-location plots
Coefficient significance tables surfaced directly in the dashboard
Cross-city performance rankings — compare model accuracy across all 20 locations
Live data refresh — pipeline re-ingests and re-fits on each session


Model Details

Algorithm: Ordinary least squares linear regression (lm())
Features: Lagged temperature, humidity, wind speed, time-of-day and seasonal encodings
Evaluation metrics: R², Adjusted R², RMSE (Root Mean Squared Error), MAE (Mean Absolute Error)
Inference: 95% prediction intervals via predict(..., interval = "prediction")
Validation: Residual normality and homoscedasticity checked per city

