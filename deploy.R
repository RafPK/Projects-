#!/usr/bin/env Rscript
# Deploy to ShinyApps.io
#
# One-time setup:
#   rsconnect::setAccountInfo(name="<YOU>", token="<TOKEN>", secret="<SECRET>")
# Then:
#   source("deploy.R")

if (!requireNamespace("rsconnect", quietly=TRUE))
  install.packages("rsconnect", repos="https://cloud.r-project.org")

rsconnect::deployApp(
  appDir        = ".",
  appName       = "canada-ds-job-market",
  appFiles      = "app.R",
  launch.browser = TRUE,
  forceUpdate   = TRUE
)
