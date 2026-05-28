#!/usr/bin/env Rscript
# Run once before launching: Rscript install_packages.R

pkgs <- c("shiny","bslib","dplyr","tidyr","ggplot2","plotly",
          "DT","scales","rvest","httr")

for (p in pkgs) {
  if (!requireNamespace(p, quietly=TRUE)) {
    message("Installing ", p, "...")
    install.packages(p, repos="https://cloud.r-project.org", quiet=TRUE)
  } else {
    message("OK  ", p)
  }
}
cat("\nAll done! Run with:  shiny::runApp('app.R')\n")
cat("Deploy with:         source('deploy.R')\n")
