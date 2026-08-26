# =============================================================================
# 04_cfs_selection.R
# Correlation-based Feature Selection (CFS) — R implementation.
#
# Replicates Weka CfsSubsetEval + BestFirst:
#   1. Pearson r of each feature with target; drop |r| < 0.10
#   2. Greedy selection by |r|; skip redundant features (inter-r > 0.80)
# Run separately for each position group.
# =============================================================================

library(tidyverse)

source("R/utils.R")

PROCESSED_DIR <- "data/processed"
OUTPUT_DIR <- "output/tables"

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

longitudinal <- readRDS(file.path(PROCESSED_DIR, "longitudinal_pairs.rds"))
feature_cols <- readRDS(file.path(PROCESSED_DIR, "feature_columns.rds"))

positions <- c("Forward", "Midfielder", "Defender")
cfs_results <- list()
cfs_summary <- tibble()

for (pos in positions) {
  message("\nCFS for ", pos, "...")

  pos_data <- longitudinal %>%
    filter(position_group == pos) %>%
    filter(!is.na(target_next))

  # Complete cases only for feature selection
  model_matrix <- pos_data %>%
    select(all_of(feature_cols)) %>%
    as.matrix()

  target <- pos_data$target_next
  complete_idx <- complete.cases(model_matrix) & !is.na(target)
  model_matrix <- model_matrix[complete_idx, , drop = FALSE]
  target <- target[complete_idx]

  message("  Complete cases: ", nrow(model_matrix))

  selected <- cfs_select(
    feature_matrix = model_matrix,
    target = target,
    min_corr = 0.10,
    max_inter_corr = 0.80
  )

  cfs_results[[pos]] <- selected

  message("  Selected ", length(selected), " features:")
  message("    ", paste(selected, collapse = ", "))

  cfs_summary <- bind_rows(
    cfs_summary,
    tibble(position_group = pos, n_selected = length(selected), features = paste(selected, collapse = ";"))
  )
}

saveRDS(cfs_results, file.path(PROCESSED_DIR, "cfs_selected_features.rds"))
write_csv(cfs_summary, file.path(OUTPUT_DIR, "cfs_r_selected_features.csv"))

message("\nCFS selection complete. Results saved to ", OUTPUT_DIR, "/")
