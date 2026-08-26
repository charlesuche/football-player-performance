# =============================================================================
# R/utils.R
# Shared helper functions for the player valuation pipeline.
# =============================================================================

# Assign each player to a single position group (Forward, Midfielder, Defender).
# FBref Pos can be multi-valued (e.g. "FW,MF"); we use priority FW > MF > DF.
assign_position_group <- function(pos_vector) {
  groups <- rep(NA_character_, length(pos_vector))

  for (i in seq_along(pos_vector)) {
    pos <- pos_vector[i]

    if (is.na(pos) || grepl("GK", pos)) {
      groups[i] <- NA_character_
    } else if (grepl("FW", pos)) {
      groups[i] <- "Forward"
    } else if (grepl("MF", pos)) {
      groups[i] <- "Midfielder"
    } else if (grepl("DF", pos)) {
      groups[i] <- "Defender"
    }
  }

  groups
}

# Convert a season total to a per-90 rate.
# minutes_90s is the number of 90-minute blocks played (FBref "Mins_Per_90").
to_per90 <- function(total, minutes_90s) {
  rate <- total / minutes_90s
  rate[is.na(total) | is.na(minutes_90s) | minutes_90s <= 0] <- NA_real_
  rate
}

# Standardise features: fit on training data, apply to both train and test.
standardize_features <- function(train_x, test_x) {
  means <- colMeans(train_x, na.rm = TRUE)
  sds <- apply(train_x, 2, sd, na.rm = TRUE)
  sds[sds == 0 | is.na(sds)] <- 1

  scale_matrix <- function(x) {
    scaled <- x
    for (j in seq_len(ncol(x))) {
      scaled[, j] <- (x[, j] - means[j]) / sds[j]
    }
    scaled
  }

  list(
    train = scale_matrix(train_x),
    test = scale_matrix(test_x),
    means = means,
    sds = sds
  )
}

# Replicate Weka CfsSubsetEval + BestFirst (simplified greedy version):
# 1. Keep features with |r| >= min_corr to target
# 2. Greedily add features sorted by |r| with target
# 3. Skip a candidate if it correlates > max_inter_corr with any selected feature
#    (keep the one with higher |r| to target)
cfs_select <- function(feature_matrix, target, min_corr = 0.10, max_inter_corr = 0.80) {
  feature_names <- colnames(feature_matrix)
  n_features <- length(feature_names)

  # Pearson correlation of each feature with the target
  target_corr <- rep(NA_real_, n_features)
  for (j in seq_len(n_features)) {
    pair <- cbind(feature_matrix[, j], target)
    pair <- pair[complete.cases(pair), , drop = FALSE]
    if (nrow(pair) >= 10) {
      target_corr[j] <- cor(pair[, 1], pair[, 2], method = "pearson")
    }
  }

  # Step 1: remove weak features
  strong_enough <- which(!is.na(target_corr) & abs(target_corr) >= min_corr)
  if (length(strong_enough) == 0) {
    return(character(0))
  }

  # Sort candidates by absolute correlation with target (descending)
  candidate_order <- strong_enough[order(-abs(target_corr[strong_enough]))]

  selected <- character(0)

  for (idx in candidate_order) {
    fname <- feature_names[idx]
    keep_feature <- TRUE

    for (sel_name in selected) {
      sel_idx <- which(feature_names == sel_name)
      pair <- cbind(feature_matrix[, idx], feature_matrix[, sel_idx])
      pair <- pair[complete.cases(pair), , drop = FALSE]

      if (nrow(pair) >= 10) {
        inter_r <- cor(pair[, 1], pair[, 2], method = "pearson")
        if (!is.na(inter_r) && abs(inter_r) > max_inter_corr) {
          # Keep whichever feature has higher |r| with the target
          if (abs(target_corr[idx]) <= abs(target_corr[sel_idx])) {
            keep_feature <- FALSE
            break
          } else {
            selected <- setdiff(selected, sel_name)
          }
        }
      }
    }

    if (keep_feature) {
      selected <- c(selected, fname)
    }
  }

  selected
}

# Regression metrics for model evaluation
compute_regression_metrics <- function(actual, predicted) {
  residuals <- actual - predicted
  ss_res <- sum(residuals^2, na.rm = TRUE)
  ss_tot <- sum((actual - mean(actual, na.rm = TRUE))^2, na.rm = TRUE)
  r2 <- 1 - (ss_res / ss_tot)

  list(
    r2 = r2,
    rmse = sqrt(mean(residuals^2, na.rm = TRUE)),
    mae = mean(abs(residuals), na.rm = TRUE)
  )
}
