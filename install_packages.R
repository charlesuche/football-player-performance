# =============================================================================
# install_packages.R
# Install required packages for the player valuation pipeline.
# Run once before starting the analysis: source("install_packages.R")
# =============================================================================

required_packages <- c(
  "worldfootballR",
  "tidyverse",
  "randomForest",
  "caret",
  "janitor",
  "ggplot2"
)

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing ", pkg, "...")
    install.packages(pkg, repos = "https://cloud.r-project.org")
  } else {
    message(pkg, " is already installed.")
  }
}

message("\nAll required packages are ready.")
