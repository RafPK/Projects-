library(shiny)
library(dplyr)
library(tidyr)
library(ggplot2)
library(plotly)
library(DT)
library(lubridate)
library(purrr)
library(httr)
library(jsonlite)

# ── City definitions ──────────────────────────────────────────
american_cities <- data.frame(
  city      = c("New York","Los Angeles","Chicago","Miami",
                "Toronto","Vancouver","Mexico City","Guadalajara",
                "Sao Paulo","Rio de Janeiro","Buenos Aires","Santiago",
                "Bogota","Lima","Caracas","Havana",
                "Montreal","Houston","Phoenix","Seattle"),
  country   = c("USA","USA","USA","USA",
                "Canada","Canada","Mexico","Mexico",
                "Brazil","Brazil","Argentina","Chile",
                "Colombia","Peru","Venezuela","Cuba",
                "Canada","USA","USA","USA"),
  latitude  = c(40.71, 34.05, 41.85, 25.77,
                43.65, 49.25, 19.43, 20.66,
               -23.55,-22.91,-34.60,-33.45,
                 4.71,-12.05, 10.48, 23.13,
                45.50, 29.76, 33.45, 47.61),
  longitude = c(-74.01,-118.24,-87.65,-80.19,
                -79.38,-123.12,-99.13,-103.35,
                -46.63, -43.17,-58.38,-70.67,
                -74.07, -77.04,-66.86,-82.38,
                -73.57, -95.37,-112.07,-122.33),
  stringsAsFactors = FALSE
)

# ── WMO weather code → readable label ────────────────────────
wmo_description <- function(code) {
  dplyr::case_when(
    is.na(code)     ~ "Unknown",
    code == 0       ~ "Clear Sky",
    code %in% 1:3   ~ "Partly Cloudy",
    code %in% 45:48 ~ "Foggy",
    code %in% 51:57 ~ "Drizzle",
    code %in% 61:67 ~ "Rain",
    code %in% 71:77 ~ "Snow",
    code %in% 80:82 ~ "Rain Showers",
    code %in% 95:99 ~ "Thunderstorm",
    TRUE            ~ "Variable"
  )
}

# ── Scrape one city from Open-Meteo (free, no API key) ───────
fetch_city_weather <- function(city_name, lat, lon) {
  url <- "https://api.open-meteo.com/v1/forecast"
  params <- list(
    latitude         = lat,
    longitude        = lon,
    hourly           = paste(c("temperature_2m","relative_humidity_2m",
                               "precipitation","wind_speed_10m",
                               "surface_pressure","cloud_cover",
                               "dew_point_2m","apparent_temperature"),
                             collapse = ","),
    current          = paste(c("temperature_2m","relative_humidity_2m",
                               "precipitation","wind_speed_10m",
                               "surface_pressure","cloud_cover",
                               "apparent_temperature","weather_code"),
                             collapse = ","),
    forecast_days    = 7,
    past_days        = 7,
    timezone         = "auto",
    temperature_unit = "celsius",
    wind_speed_unit  = "kmh",
    precipitation_unit = "mm"
  )

  resp <- tryCatch(
    httr::GET(url, query = params, httr::timeout(30)),
    error = function(e) NULL
  )
  if (is.null(resp) || httr::http_error(resp)) return(NULL)

  raw <- tryCatch(
    jsonlite::fromJSON(httr::content(resp, "text", encoding = "UTF-8")),
    error = function(e) NULL
  )
  if (is.null(raw)) return(NULL)

  # Parse timezone safely
  tz_str <- tryCatch(raw$timezone, error = function(e) "UTC")
  if (is.null(tz_str) || length(tz_str) == 0) tz_str <- "UTC"

  current_df <- data.frame(
    city                  = city_name,
    country               = NA_character_,
    latitude              = lat,
    longitude             = lon,
    fetch_time            = Sys.time(),
    current_temp          = as.numeric(raw$current$temperature_2m),
    current_apparent_temp = as.numeric(raw$current$apparent_temperature),
    current_humidity      = as.numeric(raw$current$relative_humidity_2m),
    current_precip        = as.numeric(raw$current$precipitation),
    current_wind          = as.numeric(raw$current$wind_speed_10m),
    current_pressure      = as.numeric(raw$current$surface_pressure),
    current_cloud         = as.numeric(raw$current$cloud_cover),
    weather_code          = as.integer(raw$current$weather_code),
    stringsAsFactors      = FALSE
  )

  hourly_df <- data.frame(
    city          = city_name,
    latitude      = lat,
    longitude     = lon,
    datetime      = as.POSIXct(raw$hourly$time,
                               format = "%Y-%m-%dT%H:%M", tz = tz_str),
    temperature   = as.numeric(raw$hourly$temperature_2m),
    apparent_temp = as.numeric(raw$hourly$apparent_temperature),
    humidity      = as.numeric(raw$hourly$relative_humidity_2m),
    precipitation = as.numeric(raw$hourly$precipitation),
    wind_speed    = as.numeric(raw$hourly$wind_speed_10m),
    pressure      = as.numeric(raw$hourly$surface_pressure),
    cloud_cover   = as.numeric(raw$hourly$cloud_cover),
    dew_point     = as.numeric(raw$hourly$dew_point_2m),
    stringsAsFactors = FALSE
  )

  list(current = current_df, hourly = hourly_df)
}

# ── Feature engineering ───────────────────────────────────────
clean_hourly <- function(df) {
  df %>%
    filter(!is.na(temperature)) %>%
    arrange(datetime) %>%
    mutate(
      hour          = lubridate::hour(datetime),
      day_of_year   = lubridate::yday(datetime),
      hour_sin      = sin(2 * pi * hour / 24),
      hour_cos      = cos(2 * pi * hour / 24),
      doy_sin       = sin(2 * pi * day_of_year / 365),
      doy_cos       = cos(2 * pi * day_of_year / 365),
      cloud_fraction = cloud_cover / 100,
      precip_flag   = as.integer(precipitation > 0),
      temp_lag1     = dplyr::lag(temperature, 1),
      temp_lag3     = dplyr::lag(temperature, 3),
      temp_lag6     = dplyr::lag(temperature, 6),
      temp_roll3    = (dplyr::lag(temperature, 1) +
                       dplyr::lag(temperature, 2) +
                       dplyr::lag(temperature, 3)) / 3
    ) %>%
    tidyr::drop_na(temp_lag6, temp_roll3)
}

# ── Linear regression model ───────────────────────────────────
fit_city_model <- function(df) {
  lm(
    temperature ~
      humidity + pressure + wind_speed + cloud_fraction +
      dew_point + precipitation +
      hour_sin + hour_cos + doy_sin + doy_cos +
      temp_lag1 + temp_lag3 + temp_lag6 + temp_roll3 + latitude,
    data = df
  )
}

# ── 24-hour ahead predictions ─────────────────────────────────
predict_next_24h <- function(city_name, model, last_row) {
  purrr::map_dfr(1:24, function(h) {
    fh   <- (lubridate::hour(last_row$datetime) + h) %% 24
    fdoy <- lubridate::yday(last_row$datetime + lubridate::hours(h))

    nd <- data.frame(
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

    pred <- tryCatch(
      predict(model, newdata = nd, interval = "prediction", level = 0.95),
      error = function(e) matrix(c(NA_real_, NA_real_, NA_real_),
                                 nrow = 1,
                                 dimnames = list(NULL, c("fit","lwr","upr")))
    )

    data.frame(
      city       = city_name,
      hour_ahead = h,
      datetime   = last_row$datetime + lubridate::hours(h),
      pred_temp  = round(pred[, "fit"], 2),
      lower_95   = round(pred[, "lwr"], 2),
      upper_95   = round(pred[, "upr"], 2)
    )
  }) %>%
    dplyr::filter(
      is.finite(pred_temp),
      is.finite(lower_95),
      is.finite(upper_95)
    )
}

# ── Master data loader (startup + refresh button) ─────────────
load_weather_data <- function() {
  message("Fetching real-time weather data from Open-Meteo...")

  all_current <- list()
  all_hourly  <- list()

  for (i in seq_len(nrow(american_cities))) {
    row <- american_cities[i, ]
    res <- tryCatch(
      fetch_city_weather(row$city, row$latitude, row$longitude),
      error = function(e) NULL
    )
    if (!is.null(res)) {
      res$current$country <- row$country
      all_current[[i]]    <- res$current
      all_hourly[[i]]     <- res$hourly
    }
    Sys.sleep(0.25)
  }

  if (length(all_current) == 0) stop("No weather data could be fetched.")

  raw_current <- dplyr::bind_rows(all_current)
  raw_hourly  <- dplyr::bind_rows(all_hourly) %>%
    dplyr::left_join(american_cities %>% dplyr::select(city, country), by = "city")

  # Clean hourly data per city
  hourly_clean <- raw_hourly %>%
    dplyr::group_by(city) %>%
    dplyr::arrange(datetime, .by_group = TRUE) %>%
    dplyr::group_modify(~ clean_hourly(.x)) %>%
    dplyr::ungroup()

  model_stats <- list()
  predictions <- list()
  resids_list <- list()
  coefs_list  <- list()

  for (cty in unique(hourly_clean$city)) {
    df <- hourly_clean %>% dplyr::filter(city == cty)
    if (nrow(df) < 30) next

    mdl <- tryCatch(fit_city_model(df), error = function(e) NULL)
    if (is.null(mdl)) next

    s <- summary(mdl)

    model_stats[[cty]] <- data.frame(
      city        = cty,
      n_obs       = nrow(df),
      r_squared   = round(s$r.squared,      4),
      adj_r2      = round(s$adj.r.squared,  4),
      rmse        = round(sqrt(mean(mdl$residuals^2)), 3),
      mae         = round(mean(abs(mdl$residuals)),    3),
      f_statistic = round(s$fstatistic[1],  2),
      stringsAsFactors = FALSE
    )

    last_row <- df %>% dplyr::arrange(datetime) %>% tail(1)
    predictions[[cty]] <- predict_next_24h(cty, mdl, last_row)

    resids_list[[cty]] <- data.frame(
      city      = cty,
      fitted    = as.numeric(fitted(mdl)),
      residuals = as.numeric(residuals(mdl)),
      actual    = df$temperature[seq_along(fitted(mdl))]
    )

    cf           <- as.data.frame(coef(s))
    cf$predictor <- rownames(cf)
    cf$city      <- cty
    coefs_list[[cty]] <- cf %>%
      dplyr::select(city, predictor,
                    estimate  = Estimate,
                    std_error = `Std. Error`,
                    t_value   = `t value`,
                    p_value   = `Pr(>|t|)`) %>%
      dplyr::mutate(
        significant = p_value < 0.05,
        dplyr::across(where(is.numeric), ~ round(.x, 4))
      )
  }

  stats_df <- dplyr::bind_rows(model_stats)
  preds_df <- dplyr::bind_rows(predictions)

  current_enriched <- raw_current %>%
    dplyr::left_join(
      stats_df %>% dplyr::select(city, r_squared, rmse, adj_r2),
      by = "city") %>%
    dplyr::left_join(
      american_cities %>% dplyr::select(city, latitude, longitude),
      by = "city") %>%
    dplyr::left_join(
      preds_df %>% dplyr::filter(hour_ahead == 6) %>%
        dplyr::select(city, pred_6h = pred_temp),
      by = "city") %>%
    dplyr::left_join(
      preds_df %>% dplyr::filter(hour_ahead == 24) %>%
        dplyr::select(city, pred_24h = pred_temp),
      by = "city") %>%
    dplyr::mutate(
      weather_desc = wmo_description(weather_code),
      # Ensure numeric columns are truly numeric
      dplyr::across(c(current_temp, current_apparent_temp,
                      current_humidity, current_wind,
                      current_pressure, r_squared, rmse), as.numeric)
    )

  list(
    current    = current_enriched,
    hourly     = hourly_clean,
    stats      = stats_df,
    preds      = preds_df,
    resids     = dplyr::bind_rows(resids_list),
    coefs      = dplyr::bind_rows(coefs_list),
    city_meta  = american_cities,
    scraped_at = Sys.time()
  )
}

# ── Run on startup ────────────────────────────────────────────
message("=== WeatherML Americas: initialising ===")
WX <- load_weather_data()
message(sprintf("Ready: %d cities loaded at %s UTC",
                nrow(WX$current),
                format(WX$scraped_at, "%H:%M", tz = "UTC")))
