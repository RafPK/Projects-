library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)

# ------------------------------------------------------------
# City definitions across the Americas
# ------------------------------------------------------------
american_cities <- data.frame(
  city        = c("New York", "Los Angeles", "Chicago", "Miami",
                  "Toronto", "Vancouver", "Mexico City", "Guadalajara",
                  "São Paulo", "Rio de Janeiro", "Buenos Aires", "Santiago",
                  "Bogotá", "Lima", "Caracas", "Havana",
                  "Montreal", "Houston", "Phoenix", "Seattle"),
  country     = c("USA", "USA", "USA", "USA",
                  "Canada", "Canada", "Mexico", "Mexico",
                  "Brazil", "Brazil", "Argentina", "Chile",
                  "Colombia", "Peru", "Venezuela", "Cuba",
                  "Canada", "USA", "USA", "USA"),
  continent   = rep("Americas", 20),
  latitude    = c(40.71, 34.05, 41.85, 25.77,
                  43.65, 49.25, 19.43, 20.66,
                  -23.55, -22.91, -34.60, -33.45,
                  4.71, -12.05, 10.48, 23.13,
                  45.50, 29.76, 33.45, 47.61),
  longitude   = c(-74.01, -118.24, -87.65, -80.19,
                  -79.38, -123.12, -99.13, -103.35,
                  -46.63, -43.17, -58.38, -70.67,
                  -74.07, -77.04, -66.86, -82.38,
                  -73.57, -95.37, -112.07, -122.33),
  stringsAsFactors = FALSE
)

# ------------------------------------------------------------
# Scrape current weather + 7-day hourly history per city
# ------------------------------------------------------------
fetch_city_weather <- function(city_name, lat, lon) {
  message(sprintf("  Fetching: %s (%.2f, %.2f)", city_name, lat, lon))

  # Past 7 days of hourly data for regression features
  end_date   <- Sys.Date()
  start_date <- end_date - 7

  url <- "https://api.open-meteo.com/v1/forecast"

  params <- list(
    latitude              = lat,
    longitude             = lon,
    hourly                = paste(c(
      "temperature_2m",
      "relative_humidity_2m",
      "precipitation",
      "wind_speed_10m",
      "surface_pressure",
      "cloud_cover",
      "dew_point_2m",
      "apparent_temperature"
    ), collapse = ","),
    current               = paste(c(
      "temperature_2m",
      "relative_humidity_2m",
      "precipitation",
      "wind_speed_10m",
      "surface_pressure",
      "cloud_cover",
      "apparent_temperature",
      "weather_code"
    ), collapse = ","),
    forecast_days         = 7,
    past_days             = 7,
    timezone              = "auto",
    temperature_unit      = "celsius",
    wind_speed_unit       = "kmh",
    precipitation_unit    = "mm"
  )

  resp <- tryCatch(
    GET(url, query = params, timeout(30)),
    error = function(e) NULL
  )

  if (is.null(resp) || http_error(resp)) {
    warning(sprintf("Failed to fetch data for %s", city_name))
    return(NULL)
  }

  raw <- fromJSON(content(resp, "text", encoding = "UTF-8"))

  # --- Current conditions ---
  current_df <- data.frame(
    city                  = city_name,
    fetch_time            = Sys.time(),
    current_temp          = raw$current$temperature_2m,
    current_apparent_temp = raw$current$apparent_temperature,
    current_humidity      = raw$current$relative_humidity_2m,
    current_precip        = raw$current$precipitation,
    current_wind          = raw$current$wind_speed_10m,
    current_pressure      = raw$current$surface_pressure,
    current_cloud         = raw$current$cloud_cover,
    weather_code          = raw$current$weather_code,
    stringsAsFactors      = FALSE
  )

  # --- Hourly history for regression ---
  hourly_df <- data.frame(
    city                = city_name,
    latitude            = lat,
    longitude           = lon,
    datetime            = as.POSIXct(raw$hourly$time, format = "%Y-%m-%dT%H:%M",
                                     tz = raw$timezone),
    temperature         = raw$hourly$temperature_2m,
    apparent_temp       = raw$hourly$apparent_temperature,
    humidity            = raw$hourly$relative_humidity_2m,
    precipitation       = raw$hourly$precipitation,
    wind_speed          = raw$hourly$wind_speed_10m,
    pressure            = raw$hourly$surface_pressure,
    cloud_cover         = raw$hourly$cloud_cover,
    dew_point           = raw$hourly$dew_point_2m,
    stringsAsFactors    = FALSE
  )

  list(current = current_df, hourly = hourly_df)
}

# ------------------------------------------------------------
# Main scraping loop
# ------------------------------------------------------------
scrape_all_cities <- function() {
  message("\n=== Starting Real-Time Weather Data Scraping ===")
  message(sprintf("Timestamp: %s UTC\n", format(Sys.time(), tz = "UTC")))

  all_current <- list()
  all_hourly  <- list()

  for (i in seq_len(nrow(american_cities))) {
    row    <- american_cities[i, ]
    result <- fetch_city_weather(row$city, row$latitude, row$longitude)

    if (!is.null(result)) {
      # Attach metadata
      result$current <- cbind(result$current,
                              country   = row$country,
                              latitude  = row$latitude,
                              longitude = row$longitude)
      all_current[[i]] <- result$current
      all_hourly[[i]]  <- result$hourly
    }

    Sys.sleep(0.3)   # polite delay
  }

  current_weather <- bind_rows(all_current)
  hourly_weather  <- bind_rows(all_hourly)

  # Merge city metadata into hourly
  hourly_weather <- hourly_weather %>%
    left_join(american_cities %>% select(city, country),
              by = "city")

  message(sprintf("\n✓ Scraped %d cities | %d hourly records",
                  nrow(current_weather), nrow(hourly_weather)))

  list(
    current      = current_weather,
    hourly       = hourly_weather,
    city_meta    = american_cities,
    scraped_at   = Sys.time()
  )
}

# Run and save
scraped_data <- scrape_all_cities()

saveRDS(scraped_data, "weather_scraped.rds")
message("\n✓ Saved to weather_scraped.rds")
