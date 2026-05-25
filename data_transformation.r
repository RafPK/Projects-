library(dplyr)
library(tidyr)
library(lubridate)
library(purrr)

# -------------------
# Load scraped data
# -------------------
message("=== Loading Scraped Data ===")
scraped <- readRDS("weather_scraped.rds")

hourly  <- scraped$hourly
current <- scraped$current
cities  <- scraped$city_meta

# ----------------------------
# 1. CLEAN & ENGINEER FEATURES

clean_hourly <- function(df) {
  df %>%
    # Remove rows with all-NA temperature (API gaps)
    filter(!is.na(temperature)) %>%
    mutate(
      # Time features
      hour         = hour(datetime),
      day_of_year  = yday(datetime),
      month        = month(datetime),
      is_daytime   = as.integer(hour >= 6 & hour <= 20),

      # Cyclical encoding for hour & day (sine/cosine)
      hour_sin     = sin(2 * pi * hour / 24),
      hour_cos     = cos(2 * pi * hour / 24),
      doy_sin      = sin(2 * pi * day_of_year / 365),
      doy_cos      = cos(2 * pi * day_of_year / 365),

      # Derived features
      temp_humidity_idx = temperature - 0.55 * (1 - humidity / 100) * (temperature - 14.5),
      precip_flag       = as.integer(precipitation > 0),
      cloud_fraction    = cloud_cover / 100,

      # Lag features (previous hour's temperature) — filled by group
      temp_lag1    = lag(temperature, 1),
      temp_lag3    = lag(temperature, 3),
      temp_lag6    = lag(temperature, 6),

      # Rolling 3-hour mean temperature
      temp_roll3   = (lag(temperature, 1) + lag(temperature, 2) + lag(temperature, 3)) / 3
    ) %>%
    drop_na(temp_lag6, temp_roll3)
}

message("Cleaning hourly data and engineering features...")
hourly_clean <- hourly %>%
  group_by(city) %>%
  arrange(datetime, .by_group = TRUE) %>%
  group_modify(~ clean_hourly(.x)) %>%
  ungroup()

message(sprintf("  Clean records: %d", nrow(hourly_clean)))

# ---------------------------------------------
# 2. FIT LINEAR REGRESSION — one model per city
# ---------------------------------------------
message("\n=== Fitting Linear Regression Models (per city) ===")

fit_city_model <- function(df) {
  # Predict temperature from meteorological + time features
  model <- lm(
    temperature ~
      humidity       +
      pressure       +
      wind_speed     +
      cloud_fraction +
      dew_point      +
      precipitation  +
      hour_sin       +
      hour_cos       +
      doy_sin        +
      doy_cos        +
      temp_lag1      +
      temp_lag3      +
      temp_lag6      +
      temp_roll3     +
      latitude,
    data = df
  )
  model
}

# Fit models and collect stats
city_models <- hourly_clean %>%
  group_by(city) %>%
  group_map(~ list(
    city  = .y$city,
    model = fit_city_model(.x),
    data  = .x,
    n     = nrow(.x)
  ), .keep = TRUE)

names(city_models) <- sapply(city_models, `[[`, "city")

# Extract model summaries
model_stats <- map_dfr(city_models, function(cm) {
  s   <- summary(cm$model)
  cf  <- coef(s)

  data.frame(
    city        = cm$city,
    n_obs       = cm$n,
    r_squared   = round(s$r.squared, 4),
    adj_r2      = round(s$adj.r.squared, 4),
    rmse        = round(sqrt(mean(cm$model$residuals^2)), 3),
    mae         = round(mean(abs(cm$model$residuals)), 3),
    f_statistic = round(s$fstatistic[1], 2),
    stringsAsFactors = FALSE
  )
})

message("\nModel Performance Summary:")
print(model_stats %>% arrange(desc(r_squared)), row.names = FALSE)

# ------------------------------------------------
# 3. GENERATE 24-HOUR AHEAD PREDICTIONS (per city)
# ------------------------------------------------
message("\n=== Generating 24-Hour Predictions ===")

predict_next_24h <- function(city_name, models_list, clean_df) {
  cm      <- models_list[[city_name]]
  last_row <- clean_df %>%
    filter(city == city_name) %>%
    arrange(datetime) %>%
    tail(1)

  if (nrow(last_row) == 0) return(NULL)

  future_hours <- 1:24
  preds <- map_dfr(future_hours, function(h) {
    fh    <- (hour(last_row$datetime) + h) %% 24
    fdoy  <- yday(last_row$datetime + hours(h))

    new_data <- data.frame(
      humidity       = last_row$humidity,
      pressure       = last_row$pressure,
      wind_speed     = last_row$wind_speed,
      cloud_fraction = last_row$cloud_fraction,
      dew_point      = last_row$dew_point,
      precipitation  = 0,
      hour_sin       = sin(2 * pi * fh / 24),
      hour_cos       = cos(2 * pi * fh / 24),
      doy_sin        = sin(2 * pi * fdoy / 365),
      doy_cos        = cos(2 * pi * fdoy / 365),
      temp_lag1      = last_row$temperature,
      temp_lag3      = last_row$temperature,
      temp_lag6      = last_row$temperature,
      temp_roll3     = last_row$temperature,
      latitude       = last_row$latitude
    )

    pred <- predict(cm$model, newdata = new_data, interval = "prediction", level = 0.95)

    data.frame(
      city       = city_name,
      hour_ahead = h,
      datetime   = last_row$datetime + hours(h),
      pred_temp  = round(pred[, "fit"],   2),
      lower_95   = round(pred[, "lwr"],   2),
      upper_95   = round(pred[, "upr"],   2)
    )
  })
  # Remove rows where the model produced non-finite intervals
  preds <- preds %>% filter(
    is.finite(pred_temp),
    is.finite(lower_95),
    is.finite(upper_95)
  )
  preds
}

predictions_24h <- map_dfr(
  names(city_models),
  ~ predict_next_24h(.x, city_models, hourly_clean)
)

# -------------------------------------------
# 4. COEFFICIENT TABLE (for website display)
# -------------------------------------------
coef_table <- map_dfr(city_models, function(cm) 
  cf <- as.data.frame(coef(summary(cm$model)))
  cf$predictor <- rownames(cf)
  cf$city      <- cm$city
  cf %>%
    select(city, predictor,
           estimate   = Estimate,
           std_error  = `Std. Error`,
           t_value    = `t value`,
           p_value    = `Pr(>|t|)`) %>%
    mutate(
      significant = p_value < 0.05,
      across(where(is.numeric), ~ round(.x, 4))
    )
}, .id = NULL)

# -----------------------------------------
# 5. CURRENT CONDITIONS TABLE 
# -----------------------------------------
current_enriched <- current %>%
  left_join(model_stats %>% select(city, r_squared, rmse, adj_r2),
            by = "city") %>%
  left_join(cities %>% select(city, latitude, longitude),
            by = "city") %>%
  left_join(
    predictions_24h %>%
      filter(hour_ahead == 6) %>%
      select(city, pred_6h = pred_temp),
    by = "city"
  ) %>%
  left_join(
    predictions_24h %>%
      filter(hour_ahead == 24) %>%
      select(city, pred_24h = pred_temp),
    by = "city"
  )

# ---------------------------------
# 6. RESIDUALS for diagnostic plot
# ---------------------------------
residuals_df <- map_dfr(city_models, function(cm) {
  data.frame(
    city      = cm$city,
    fitted    = fitted(cm$model),
    residuals = residuals(cm$model),
    actual    = cm$data$temperature[seq_along(fitted(cm$model))]
  )
})

# -------------------------
# Save transformed outputs
# -------------------------
transformed <- list
  hourly_clean    = hourly_clean,
  current_enriched = current_enriched,
  model_stats     = model_stats,
  predictions_24h = predictions_24h,
  coef_table      = coef_table,
  residuals_df    = residuals_df,
  city_models     = city_models,
  processed_at    = Sys.time()
)

saveRDS(transformed, "weather_transformed.rds")
message("\n✓ Saved to weather_transformed.rds")
message(sprintf("  Cities modelled:     %d", length(city_models)))
message(sprintf("  24h predictions:     %d rows", nrow(predictions_24h)))
message(sprintf("  Avg R²:              %.4f", mean(model_stats$r_squared)))
