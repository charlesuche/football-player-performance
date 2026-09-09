# =============================================================================
# 05_modeling.R
# Position-specific Random Forest models.
#
# Three versions per position:
#   1. Baseline — all available features
#   2. Model A  — Weka CFS selected features (from output/weka/weka_selected_features.csv)
#   3. Model B  — R CFS selected features
#
# Evaluation: 80/20 train-test split, R², RMSE, MAE, permutation importance.
# =============================================================================

library(tidyverse)
library(randomForest)

source("R/utils.R")

PROCESSED_DIR <- "data/processed"
OUTPUT_DIR <- "output/tables"
WEKA_FEATURES_FILE <- "output/weka/weka_selected_features.csv"

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

longitudinal <- readRDS(file.path(PROCESSED_DIR, "longitudinal_pairs.rds"))
feature_cols <- readRDS(file.path(PROCESSED_DIR, "feature_columns.rds"))
cfs_r <- readRDS(file.path(PROCESSED_DIR, "cfs_selected_features.rds"))



weka_features <- list()
if (file.exists(WEKA_FEATURES_FILE)) {
  weka_df <- read_csv(WEKA_FEATURES_FILE, show_col_types = FALSE)
  for (pos in unique(weka_df$position_group)) {
    weka_features[[pos]] <- weka_df %>%
      filter(position_group == pos) %>%
      pull(feature)
  }
  message("Loaded Weka CFS features from ", WEKA_FEATURES_FILE)
} else {
  message("No Weka features file found. Model A will be skipped.")
  message("Run scripts/07_export_weka.R, then fill in weka_selected_features.csv")
}

positions <- c("Forward", "Midfielder", "Defender")
set.seed(42)

results_table <- tibble()
importance_table <- tibble()
predictions_table <- tibble()

# --- Train and evaluate one model -------------------------------------------

fit_rf_model <- function(train_x, train_y, test_x, test_y, ntree = 500) {
  mtry_val <- max(1, floor(sqrt(ncol(train_x))))

  rf_model <- randomForest(
    x = train_x,
    y = train_y,
    ntree = ntree,
    mtry = mtry_val,
    importance = TRUE
  )

  #plot(rf_model, main = "OOB Error vs Number of Trees")
  
  predictions <- predict(rf_model, test_x)
  metrics <- compute_regression_metrics(test_y, predictions)

  # Permutation importance (% increase in MSE) from randomForest
  imp <- importance(rf_model, type = 1)
  imp_df <- tibble(
    feature = rownames(imp),
    importance_pct_inc_mse = imp[, 1]
  ) %>%
    arrange(desc(importance_pct_inc_mse))

  list(
    model = rf_model,
    predictions = predictions,
    metrics = metrics,
    importance = imp_df
  )
}

# --- Run models for each position and feature set ---------------------------

model_configs <- list(
  Baseline = "all",
  Model_A_Weka_CFS = "weka",
  Model_B_R_CFS = "r_cfs"
)

for (pos in positions) {
  message("\n=== ", pos, " ===")
  
  pos_data <- longitudinal %>%
    filter(position_group == pos) %>%
    filter(!is.na(target_next))
  
  # ── Fix: create one fixed split for this position ──────
  # All three models (Baseline, Weka, R CFS) use the
  # exact same train and test rows
  set.seed(42)
  n_pos <- nrow(pos_data)
  pos_train_idx <- sample(seq_len(n_pos), size = floor(0.8 * n_pos))
  pos_test_idx  <- setdiff(seq_len(n_pos), pos_train_idx)
  
  cat(sprintf("  Fixed split: %d train / %d test\n",
              length(pos_train_idx), length(pos_test_idx)))
  # ────────────────────────────────────────────────────────
  
  feature_sets <- list(
    Baseline      = feature_cols,
    Model_B_R_CFS = cfs_r[[pos]]
  )
  
  if (pos %in% names(weka_features) && length(weka_features[[pos]]) > 0) {
    feature_sets$Model_A_Weka_CFS <- weka_features[[pos]]
  }
  
  for (model_name in names(feature_sets)) {
    feats <- feature_sets[[model_name]]
    feats <- feats[feats %in% names(pos_data)]
    
    if (length(feats) < 2) next
    
    # ── Use the fixed split indices ─────────────────────
    model_df <- pos_data %>%
      select(target_next, all_of(feats))
    
    # Apply the fixed split — same rows every model
    train <- model_df[pos_train_idx, ]
    test  <- model_df[pos_test_idx,  ]
    
    # Drop NA within each split separately
    train <- drop_na(train)
    test  <- drop_na(test)
    # ────────────────────────────────────────────────────
    
    if (nrow(train) < 50 || nrow(test) < 10) {
      message("  Skipping ", model_name, " (too few complete cases)")
      next
    }
    
    train_x <- as.matrix(train[, feats, drop = FALSE])
    test_x  <- as.matrix(test[,  feats, drop = FALSE])
    train_y <- train$target_next
    test_y  <- test$target_next
    
    scaled <- standardize_features(train_x, test_x)
    
    message("  ", model_name, ": ", length(feats), " features, ",
            nrow(train), " train / ", nrow(test), " test")
    
    fit <- fit_rf_model(scaled$train, train_y, scaled$test, test_y)
    

    results_table <- bind_rows(
      results_table,
      tibble(
        position_group = pos,
        model = model_name,
        n_features = length(feats),
        n_train = nrow(train),
        n_test = nrow(test),
        r2 = fit$metrics$r2,
        rmse = fit$metrics$rmse,
        mae = fit$metrics$mae
      )
    )

    importance_table <- bind_rows(
      importance_table,
      fit$importance %>%
        mutate(position_group = pos, model = model_name)
    )

    predictions_table <- bind_rows(
      predictions_table,
      tibble(
        position_group = pos,
        model = model_name,
        actual = test_y,
        predicted = fit$predictions
      )
    )

    message("    R² = ", round(fit$metrics$r2, 3),
            ", RMSE = ", round(fit$metrics$rmse, 3),
            ", MAE = ", round(fit$metrics$mae, 3))
  }
}

# Save all model outputs
write_csv(results_table, file.path(OUTPUT_DIR, "model_results.csv"))
write_csv(importance_table, file.path(OUTPUT_DIR, "feature_importance.csv"))
write_csv(predictions_table, file.path(OUTPUT_DIR, "predictions.csv"))

saveRDS(results_table, file.path(PROCESSED_DIR, "model_results.rds"))
saveRDS(importance_table, file.path(PROCESSED_DIR, "feature_importance.rds"))
saveRDS(predictions_table, file.path(PROCESSED_DIR, "predictions.rds"))

message("\nModeling complete. Results saved to ", OUTPUT_DIR, "/")
