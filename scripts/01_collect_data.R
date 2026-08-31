# =============================================================================
# 01_collect_data.R
# FBref via worldfootballR.
#
# Seasons 2018-2024 correspond to 2017/18 through 2023/24 (season end year).
# collect one file per stat type, then merge them in the cleaning step.
# =============================================================================

source("install_packages.R")

library(worldfootballR)
library(tidyverse)
library(janitor)

# Config
SEASONS <- 2018:2024
STAT_TYPES <- c(
  "standard", "shooting", "passing",
  "defense", "possession", "misc"
)
RAW_DIR <- "data/raw"

dir.create(RAW_DIR, recursive = TRUE, showWarnings = FALSE)

for (stat_type in STAT_TYPES) {
  outfile <- file.path(RAW_DIR, paste0("big5_player_", stat_type, ".rds"))

  if (file.exists(outfile)) {
    message("Skipping ", stat_type, " (already downloaded: ", outfile, ")")
    next
  }

  message("Downloading stat_type = ", stat_type, " ...")

  df <- load_fb_big5_advanced_season_stats(
    season_end_year = SEASONS,
    stat_type = stat_type,
    team_or_player = "player"
  )

  df <- df %>%
    clean_names() %>%
    mutate(stat_type = stat_type)

  saveRDS(df, outfile)
  message("  Saved ", nrow(df), " rows to ", outfile)
}
