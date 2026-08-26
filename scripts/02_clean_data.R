# =============================================================================
# 02_clean_data.R
# Merge stat types, exclude goalkeepers, filter by playing time,
# and aggregate mid-season transfers using minutes-weighted per-90 averages.
# =============================================================================

library(tidyverse)
library(janitor)

source("R/utils.R")

RAW_DIR <- "data/raw"
PROCESSED_DIR <- "data/processed"
MIN_MINUTES_SEASON <- 450

dir.create(PROCESSED_DIR, recursive = TRUE, showWarnings = FALSE)

# --- Load all raw stat tables ------------------------------------------------

load_raw <- function(stat_type) {
  path <- file.path(RAW_DIR, paste0("big5_player_", stat_type, ".rds"))
  if (!file.exists(path)) {
    stop("Missing raw file: ", path, ". Run scripts/01_collect_data.R first.")
  }
  readRDS(path)
}

standard <- load_raw("standard")
shooting <- load_raw("shooting")
passing  <- load_raw("passing")
defense  <- load_raw("defense")
possession <- load_raw("possession")
misc     <- load_raw("misc")

message("Loaded raw tables:")
message("  standard:   ", nrow(standard), " rows")
message("  shooting:   ", nrow(shooting), " rows")
message("  passing:    ", nrow(passing), " rows")
message("  defense:    ", nrow(defense), " rows")
message("  possession: ", nrow(possession), " rows")
message("  misc:       ", nrow(misc), " rows")

# --- Build a player-club-season base from standard stats ---------------------

# Standard stats use min_playing for total minutes and already include per-90
# columns (suffix _per). Other tables use mins_per_90 as minutes/90.
base <- standard %>%
  select(
    season_end_year, comp, squad, player, nation, pos, age, born,
    url, min_playing,
    gls, ast, gls_per, ast_per,
    prg_c_progression, prg_p_progression, prg_r_progression,
    x_g_expected, x_ag_expected, npx_g_expected,
    x_g_per, x_ag_per, npx_g_per
  ) %>%
  mutate(
    position_group = assign_position_group(pos),
    minutes_90s = min_playing / 90
  ) %>%
  filter(!is.na(position_group))  # removes goalkeepers

# --- Helper: add per-90 columns from raw season totals -----------------------

add_per90_cols <- function(df, id_cols, minute_col, count_cols, suffix = "_p90") {
  result <- df

  for (col in count_cols) {
    if (col %in% names(result)) {
      new_name <- paste0(col, suffix)
      result[[new_name]] <- to_per90(result[[col]], result[[minute_col]])
    }
  }

  result
}

# Shooting: per-90 from raw counts
shooting_clean <- shooting %>%
  select(url, season_end_year, squad,
         sh_standard, so_t_standard, dist_standard,
         npx_g_per_sh_expected, mins_per_90) %>%
  rename(minutes_90s_sh = mins_per_90)

shooting_clean <- add_per90_cols(
  shooting_clean,
  id_cols = c("url", "season_end_year", "squad"),
  minute_col = "minutes_90s_sh",
  count_cols = c("sh_standard", "so_t_standard")
)

# Passing: per-90 from raw counts
passing_clean <- passing %>%
  select(
    url, season_end_year, squad, mins_per_90,
    cmp_percent_total, kp, final_third, ppa, prog, x_ag
  ) %>%
  rename(minutes_90s_pa = mins_per_90)

passing_clean <- add_per90_cols(
  passing_clean,
  id_cols = c("url", "season_end_year", "squad"),
  minute_col = "minutes_90s_pa",
  count_cols = c("kp", "final_third", "ppa", "prog")
)

# Defense: per-90 from raw counts
defense_clean <- defense %>%
  select(
    url, season_end_year, squad, mins_per_90,
    tkl_tackles, tkl_w_tackles, def_3rd_tackles, mid_3rd_tackles,
    att_3rd_tackles, blocks_blocks, int, clr, err
  ) %>%
  rename(minutes_90s_de = mins_per_90)

defense_clean <- add_per90_cols(
  defense_clean,
  id_cols = c("url", "season_end_year", "squad"),
  minute_col = "minutes_90s_de",
  count_cols = c(
    "tkl_tackles", "tkl_w_tackles", "def_3rd_tackles", "mid_3rd_tackles",
    "att_3rd_tackles", "blocks_blocks", "int", "clr", "err"
  )
)

# Possession: per-90 from raw counts
possession_clean <- possession %>%
  select(
    url, season_end_year, squad, mins_per_90,
    touches_touches, att_pen_touches, att_take, succ_take,
    prg_c_carries, mis_carries, dis_carries, prg_r_receiving
  ) %>%
  rename(minutes_90s_po = mins_per_90)

possession_clean <- add_per90_cols(
  possession_clean,
  id_cols = c("url", "season_end_year", "squad"),
  minute_col = "minutes_90s_po",
  count_cols = c(
    "touches_touches", "att_pen_touches", "att_take", "succ_take",
    "prg_c_carries", "mis_carries", "dis_carries", "prg_r_receiving"
  )
)

# Misc: per-90 from raw counts
misc_clean <- misc %>%
  select(
    url, season_end_year, squad, mins_per_90,
    fls, fld, recov, won_aerial, lost_aerial
  ) %>%
  rename(minutes_90s_mi = mins_per_90)

misc_clean <- add_per90_cols(
  misc_clean,
  id_cols = c("url", "season_end_year", "squad"),
  minute_col = "minutes_90s_mi",
  count_cols = c("fls", "fld", "recov", "won_aerial", "lost_aerial")
)

# --- Merge all stat types at player-club-season level ------------------------

player_club <- base %>%
  left_join(shooting_clean, by = c("url", "season_end_year", "squad")) %>%
  left_join(passing_clean, by = c("url", "season_end_year", "squad")) %>%
  left_join(defense_clean, by = c("url", "season_end_year", "squad")) %>%
  left_join(possession_clean, by = c("url", "season_end_year", "squad")) %>%
  left_join(misc_clean, by = c("url", "season_end_year", "squad"))

# Rename key per-90 columns to readable names used throughout the pipeline
player_club <- player_club %>%
  rename(
    goals_p90 = gls_per,
    assists_p90 = ast_per,
    xg_p90 = x_g_per,
    xag_p90 = x_ag_per,
    npxg_p90 = npx_g_per,
    prog_passes_p90 = prg_p_progression,
    prog_carries_p90 = prg_c_progression,
    prog_receptions_p90 = prg_r_progression,
    shots_p90 = sh_standard_p90,
    sot_p90 = so_t_standard_p90,
    shot_distance = dist_standard,
    npxg_per_shot = npx_g_per_sh_expected,
    pass_completion_pct = cmp_percent_total,
    key_passes_p90 = kp_p90,
    passes_final_third_p90 = final_third_p90,
    passes_pen_area_p90 = ppa_p90,
    progressive_passes_p90 = prog_p90,
    tackles_p90 = tkl_tackles_p90,
    tackles_won_p90 = tkl_w_tackles_p90,
    tackles_def_third_p90 = def_3rd_tackles_p90,
    tackles_mid_third_p90 = mid_3rd_tackles_p90,
    tackles_att_third_p90 = att_3rd_tackles_p90,
    blocks_p90 = blocks_blocks_p90,
    interceptions_p90 = int_p90,
    clearances_p90 = clr_p90,
    errors_p90 = err_p90,
    touches_p90 = touches_touches_p90,
    pen_area_touches_p90 = att_pen_touches_p90,
    dribbles_att_p90 = att_take_p90,
    dribbles_succ_p90 = succ_take_p90,
    progressive_carries_p90 = prg_c_carries_p90,
    miscontrols_p90 = mis_carries_p90,
    dispossessed_p90 = dis_carries_p90,
    prog_receptions_po_p90 = prg_r_receiving_p90,
    fouls_committed_p90 = fls_p90,
    fouls_drawn_p90 = fld_p90,
    ball_recoveries_p90 = recov_p90,
    aerials_won_p90 = won_aerial_p90,
    aerials_lost_p90 = lost_aerial_p90
  )

# --- Filter: minimum 450 minutes at a single club entry ----------------------
player_club <- player_club %>%
  filter(min_playing >= MIN_MINUTES_SEASON)

message("After 450-min filter (club level): ", nrow(player_club), " rows")

# --- Aggregate mid-season transfers to player-season level -------------------
# Weighted average of per-90 stats, weighted by minutes at each club.

per90_cols <- c(
  "goals_p90", "assists_p90", "xg_p90", "xag_p90", "npxg_p90",
  "prog_passes_p90", "prog_carries_p90", "prog_receptions_p90",
  "shots_p90", "sot_p90", "npxg_per_shot", "shot_distance",
  "pass_completion_pct", "key_passes_p90", "passes_final_third_p90",
  "passes_pen_area_p90", "progressive_passes_p90",
  "tackles_p90", "tackles_won_p90", "tackles_def_third_p90",
  "tackles_mid_third_p90", "tackles_att_third_p90",
  "blocks_p90", "interceptions_p90", "clearances_p90", "errors_p90",
  "touches_p90", "pen_area_touches_p90", "dribbles_att_p90",
  "dribbles_succ_p90", "progressive_carries_p90", "miscontrols_p90",
  "dispossessed_p90", "fouls_committed_p90", "fouls_drawn_p90",
  "ball_recoveries_p90", "aerials_won_p90", "aerials_lost_p90"
)

rate_cols <- c(per90_cols, "pass_completion_pct", "npxg_per_shot", "shot_distance", "prog_receptions_po_p90")
rate_cols <- unique(rate_cols)
rate_cols <- rate_cols[rate_cols %in% names(player_club)]

player_seasons <- player_club %>%
  group_by(url, season_end_year) %>%
  summarise(
    player = first(player),
    comp = paste(unique(comp), collapse = ";"),
    squads = paste(unique(squad), collapse = ";"),
    position_group = names(sort(table(position_group), decreasing = TRUE))[1],
    pos = first(pos),
    total_minutes = sum(min_playing, na.rm = TRUE),
    n_clubs = n(),
    across(all_of(rate_cols), ~ weighted.mean(.x, min_playing, na.rm = TRUE)),
    .groups = "drop"
  )

message("Player-season rows after transfer aggregation: ", nrow(player_seasons))

# Save cleaned player-season data
saveRDS(player_seasons, file.path(PROCESSED_DIR, "player_seasons_clean.rds"))
write_csv(player_seasons, file.path(PROCESSED_DIR, "player_seasons_clean.csv"))

message("Saved cleaned data to ", PROCESSED_DIR, "/")
