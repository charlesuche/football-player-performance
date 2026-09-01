# =============================================================================
# 03_feature_engineering.R
# Build composite features and create longitudinal season N -> N+1 pairs.
#
# Targets:
#   Forward / Midfielder: xgc_p90 in season N+1 (xG + xAG per 90)
#   Defender:             def_actions_p90 in season N+1
# =============================================================================

library(tidyverse)

source("R/utils.R")

PROCESSED_DIR <- "data/processed"
MIN_MINUTES_LONGITUDINAL <- 900

player_seasons <- readRDS(file.path(PROCESSED_DIR, "player_seasons_clean.rds"))

# --- Composite features (season N predictors) --------------------------------

player_seasons <- player_seasons %>%
  mutate(
    # Offensive composites
    gc_p90 = goals_p90 + assists_p90,
    xgc_p90 = xg_p90 + xag_p90,

    # Defensive composite (addresses Nsolo's defender gap)
    def_actions_p90 = tackles_won_p90 + interceptions_p90 + blocks_p90 + clearances_p90,

    # Efficiency ratios (handle division by zero)
    dribble_success_rate = ifelse(
      dribbles_att_p90 > 0, dribbles_succ_p90 / dribbles_att_p90, 0
    ),
    aerial_efficiency = ifelse(
      (aerials_won_p90 + aerials_lost_p90) > 0,
      aerials_won_p90 / (aerials_won_p90 + aerials_lost_p90),
      0
    ),
    discipline_ratio = ifelse(
      fouls_committed_p90 > 0, fouls_drawn_p90 / fouls_committed_p90, 0
    )
  )

# --- Feature columns used as predictors --------------------------------------

feature_cols <- c(
  "goals_p90", "assists_p90", "gc_p90", "xg_p90", "xag_p90",
  "xgc_p90", "npxg_p90",
  
  "prog_passes_p90", "prog_carries_p90", "prog_receptions_p90",
  
  "shots_p90", "sot_p90", "npxg_per_shot", "shot_distance",
  
  "pass_completion_pct", "key_passes_p90", "passes_final_third_p90",
  "passes_pen_area_p90",
  
  "tackles_p90", "tackles_won_p90", "tackles_def_third_p90",
  "tackles_mid_third_p90", "tackles_att_third_p90",
  "blocks_p90", "interceptions_p90", "clearances_p90", "errors_p90",
  "def_actions_p90",
  
  "touches_p90", "pen_area_touches_p90", "dribbles_att_p90",
  "dribbles_succ_p90", "dribble_success_rate",
  "miscontrols_p90", "dispossessed_p90",
  
  "fouls_committed_p90", "fouls_drawn_p90", "discipline_ratio",
  "ball_recoveries_p90", "aerials_won_p90", "aerials_lost_p90",
  "aerial_efficiency"
)
length(feature_cols)
feature_cols <- feature_cols[feature_cols %in% names(player_seasons)]

# --- Build longitudinal pairs via self-join (season N -> season N+1) --------

# Season N+1 targets and minutes
next_season <- player_seasons %>%
  transmute(
    url,
    season_n = season_end_year - 1L,
    season_n1 = season_end_year,
    minutes_n1 = total_minutes,
    xgc_p90_n1 = xgc_p90,
    def_actions_p90_n1 = def_actions_p90
  )

# Season N predictors joined to season N+1 outcomes
longitudinal <- player_seasons %>%
  rename(minutes_n = total_minutes, season_n = season_end_year) %>%
  inner_join(next_season, by = c("url", "season_n")) %>%
  filter(minutes_n >= MIN_MINUTES_LONGITUDINAL, minutes_n1 >= MIN_MINUTES_LONGITUDINAL) %>%
  mutate(
    target_name = if_else(
      position_group %in% c("Forward", "Midfielder"),
      "xgc_p90_next",
      "def_actions_p90_next"
    ),
    target_next = if_else(
      position_group %in% c("Forward", "Midfielder"),
      xgc_p90_n1,
      def_actions_p90_n1
    )
  ) %>%
  filter(!is.na(target_next)) %>%
  select(
    url, player, position_group, season_n, season_n1,
    minutes_n, minutes_n1, target_name, target_next,
    all_of(feature_cols)
  )

message("Longitudinal pairs created: ", nrow(longitudinal))
message("  Forward:     ", sum(longitudinal$position_group == "Forward"))
message("  Midfielder:  ", sum(longitudinal$position_group == "Midfielder"))
message("  Defender:    ", sum(longitudinal$position_group == "Defender"))

# Save outputs
saveRDS(player_seasons, file.path(PROCESSED_DIR, "player_seasons_features.rds"))
saveRDS(longitudinal, file.path(PROCESSED_DIR, "longitudinal_pairs.rds"))
saveRDS(feature_cols, file.path(PROCESSED_DIR, "feature_columns.rds"))

write_csv(longitudinal, file.path(PROCESSED_DIR, "longitudinal_pairs.csv"))

message("Saved feature-engineered data to ", PROCESSED_DIR, "/")
