# =============================================================================
# run_analysis.R
# Master script: run the full player valuation pipeline end-to-end.
#
# Usage:
#   setwd("/path/to/player_value")
#   source("run_analysis.R")
# =============================================================================

message("============================================================")
message("Player Valuation in European Football — Revisited")
message("TDDE64 | Linköping University")
message("============================================================\n")

start_time <- Sys.time()

steps <- c(
  "scripts/01_collect_data.R",
  "scripts/02_clean_data.R",
  "scripts/03_feature_engineering.R",
  "scripts/04_cfs_selection.R",
  "scripts/05_modeling.R",
  "scripts/06_visualize.R",
  "scripts/07_export_weka.R",
  "scripts/08_discussion.R"
)

for (step in steps) {
  message("\n------------------------------------------------------------")
  message("Running: ", step)
  message("------------------------------------------------------------")
  source(step)
}

elapsed <- difftime(Sys.time(), start_time, units = "mins")

message("\n============================================================")
message("Pipeline complete in ", round(elapsed, 1), " minutes")
message("============================================================")
message("\nOutputs:")
message("  Tables:   output/tables/")
message("  Figures:  output/figures/")
message("  Weka:     output/weka/")
message("\nNext steps:")
message("  1. Review output/tables/model_results.csv")
message("  2. Run Weka CFS (see output/weka/WEA_INSTRUCTIONS.txt)")
message("  3. Fill in output/weka/weka_selected_features.csv")
message("  4. Re-run scripts/05_modeling.R and scripts/06_visualize.R")
