# =============================================================================
# 07_export_weka.R
# Export longitudinal data as ARFF files for Weka 3.x feature selection.
#
# After running CFS in Weka, record selected features in:
#   output/weka/weka_selected_features.csv
#
# Then re-run scripts/05_modeling.R to include Model A (Weka CFS).
# =============================================================================

library(tidyverse)

PROCESSED_DIR <- "data/processed"
WEKA_DIR <- "output/weka"

dir.create(WEKA_DIR, recursive = TRUE, showWarnings = FALSE)

longitudinal <- readRDS(file.path(PROCESSED_DIR, "longitudinal_pairs.rds"))
feature_cols <- readRDS(file.path(PROCESSED_DIR, "feature_columns.rds"))

positions <- c("Forward", "Midfielder", "Defender")

# --- Write ARFF files (Weka native format) ----------------------------------

write_arff <- function(data, features, target_col, filepath) {
  # ARFF header
  lines <- c(
    paste0("@RELATION player_valuation"),
    ""
  )

  for (feat in features) {
    lines <- c(lines, paste0("@ATTRIBUTE ", feat, " NUMERIC"))
  }
  lines <- c(lines, paste0("@ATTRIBUTE ", target_col, " NUMERIC"))
  lines <- c(lines, "", "@DATA")

  # Data rows
  for (i in seq_len(nrow(data))) {
    vals <- c(
      sapply(features, function(f) data[[f]][i]),
      data[[target_col]][i]
    )
    vals[is.na(vals)] <- "?"
    lines <- c(lines, paste(vals, collapse = ","))
  }

  writeLines(lines, filepath)
}

for (pos in positions) {
  pos_data <- longitudinal %>%
    filter(position_group == pos) %>%
    filter(!is.na(target_next)) %>%
    select(all_of(feature_cols), target_next) %>%
    drop_na()

  arff_path <- file.path(WEKA_DIR, paste0(tolower(pos), "_longitudinal.arff"))
  write_arff(pos_data, feature_cols, "target_next", arff_path)
  message("Exported ", nrow(pos_data), " rows to ", arff_path)

  # Also export CSV for convenience
  csv_path <- file.path(WEKA_DIR, paste0(tolower(pos), "_longitudinal.csv"))
  write_csv(pos_data, csv_path)
}

# --- Create template for Weka-selected features -----------------------------

template <- tibble(
  position_group = character(),
  feature = character()
)

# Pre-fill with example structure (user replaces after Weka run)
for (pos in positions) {
  template <- bind_rows(
    template,
    tibble(position_group = pos, feature = paste0("# ADD WEA CFS FEATURES FOR ", toupper(pos), " HERE"))
  )
}

template_path <- file.path(WEKA_DIR, "weka_selected_features.csv")
if (!file.exists(template_path)) {
  write_csv(template, template_path)
  message("\nCreated template: ", template_path)
} else {
  message("\nWeka features file already exists: ", template_path)
}

# --- Weka instructions --------------------------------------------------------

instructions <- c(
  "Weka CFS Feature Selection Instructions",
  "========================================",
  "",
  "For each position ARFF file in output/weka/:",
  "",
  "1. Open Weka Explorer",
  "2. Preprocess tab -> Open file -> select e.g. forward_longitudinal.arff",
  "3. Classify tab -> Choose: weka.classifiers.meta.AttributeSelectedClassifier",
  "4. Click the classifier name to configure:",
  "   - evaluator: CfsSubsetEval",
  "   - search method: BestFirst",
  "5. Click 'Start' (use cross-validation or percentage split as preferred)",
  "6. In the output, note the 'Attributes' line listing selected features",
  "7. Add each selected feature to output/weka/weka_selected_features.csv:",
  "     position_group,feature",
  "     Forward,xgc_p90",
  "     Forward,shots_p90",
  "     ...",
  "",
  "8. Re-run: source('scripts/05_modeling.R')",
  "",
  "Compare Model A (Weka CFS) vs Model B (R CFS) in output/tables/model_results.csv"
)

writeLines(instructions, file.path(WEKA_DIR, "WEA_INSTRUCTIONS.txt"))
message("Weka instructions written to ", WEKA_DIR, "/WEA_INSTRUCTIONS.txt")
message("\nExport complete.")
