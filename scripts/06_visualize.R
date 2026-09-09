# =============================================================================
# 06_visualize.R
# Generate figures for the player valuation analysis.
#
# Figures:
#   1. R² comparison across models and positions
#   2. Parsimony curve (R² vs number of features)
#   3. Feature importance by position
#   4. Predicted vs actual scatter plots
#   5. Year-on-year stability (target distribution by season pair)
# =============================================================================

library(tidyverse)
library(ggplot2)

OUTPUT_DIR <- "output/tables"
FIGURE_DIR <- "output/figures"
PROCESSED_DIR <- "data/processed"

dir.create(FIGURE_DIR, recursive = TRUE, showWarnings = FALSE)

results <- read_csv(file.path(OUTPUT_DIR, "model_results.csv"), show_col_types = FALSE)
importance <- read_csv(file.path(OUTPUT_DIR, "feature_importance.csv"), show_col_types = FALSE)
predictions <- read_csv(file.path(OUTPUT_DIR, "predictions.csv"), show_col_types = FALSE)
longitudinal <- readRDS(file.path(PROCESSED_DIR, "longitudinal_pairs.rds"))

theme_set(theme_minimal(base_size = 12))

# --- 1. R² comparison bar chart ---------------------------------------------

p_r2 <- results %>%
  mutate(
    position_group = factor(position_group,
                            levels = c("Forward","Midfielder","Defender")),
    model = factor(model,
                   levels = c("Baseline","Model_A_Weka_CFS","Model_B_R_CFS"))
  ) %>%
  ggplot(aes(x = position_group, y = r2, fill = model)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = round(r2, 3)),
            position = position_dodge(width = 0.8),
            vjust = -0.4, size = 3.5, fontface = "bold") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  scale_fill_manual(
    values = c("Baseline"         = "#4DAF4A",
               "Model_A_Weka_CFS" = "#377EB8",
               "Model_B_R_CFS"    = "#E41A1C"),
    labels = c("Baseline", "Weka CFS", "R CFS")
  ) +
  ylim(0, 0.75) +
  labs(
    title   = "Random Forest R² by Position and Feature Selection Method",
    subtitle = "80/20 train-test split | Season N predicts Season N+1",
    x = "Position Group",
    y = expression(R^2),
    fill = "Model"
  )

ggsave(file.path(FIGURE_DIR, "01_r2_comparison.png"), p_r2, width = 10, height = 6, dpi = 150)
p_r2

# --- 2. Parsimony curve: R² vs number of features ---------------------------

p_parsimony <- results %>%
  mutate(
    position_group = factor(position_group,
                            levels = c("Forward","Midfielder","Defender")),
    model = factor(model,
                   levels = c("Baseline","Model_A_Weka_CFS","Model_B_R_CFS"),
                   labels = c("Baseline","Weka CFS","R CFS"))
  ) %>%
  ggplot(aes(x = n_features, y = r2,
             color = position_group, shape = model, group = position_group)) +
  geom_line(linetype = "dashed", alpha = 0.6, linewidth = 0.8) +
  geom_point(size = 4) +
  geom_text(aes(label = round(r2, 3)),
            vjust = -0.9, size = 3, show.legend = FALSE) +
  scale_color_manual(
    values = c("Forward"    = "#E41A1C",
               "Midfielder" = "#377EB8",
               "Defender"   = "#4DAF4A"),
    name = "Position"
  ) +
  scale_shape_manual(
    values = c("Baseline" = 16, "Weka CFS" = 17, "R CFS" = 15),
    name = "Model"
  ) +
  scale_x_continuous(breaks = c(3, 4, 6, 19, 25, 33, 42)) +
  ylim(0.40, 0.68) +
  labs(
    title    = "Parsimony Curve: Model Performance vs Feature Count",
    subtitle = "Do fewer CFS-selected features match the full baseline?",
    x = "Number of Features",
    y = expression(R^2)
  )

ggsave("output/figures/02_parsimony_curve.png", p_parsimony,
       width = 10, height = 6, dpi = 150)

ggsave(file.path(FIGURE_DIR, "02_parsimony_curve.png"), p_parsimony, width = 10, height = 6, dpi = 150)
p_parsimony
# --- 3. Feature importance (top 10 per position, Baseline model) ------------

top_importance <- importance %>%
  filter(model == "Baseline") %>%
  mutate(position_group = factor(position_group, levels = c("Forward", "Midfielder", "Defender"))) %>%
  group_by(position_group) %>%
  slice_max(importance_pct_inc_mse, n = 10) %>%
  ungroup() %>%
  mutate(feature = reorder(feature, importance_pct_inc_mse))

library(tidytext) # Add this at the top of 06_visualize.R

if (nrow(top_importance) > 0) {
  p_importance <- top_importance %>%
    ggplot(aes(x = importance_pct_inc_mse,
               y = reorder_within(feature, importance_pct_inc_mse,
                                  position_group),
               fill = position_group)) +
    geom_col(show.legend = FALSE) +
    facet_wrap(~ position_group, scales = "free_y") +
    scale_y_reordered() +
    scale_fill_manual(values = c(
      "Forward"    = "red",
      "Midfielder" = "blue",
      "Defender"   = "green"
    )) +
    labs(
      title    = "Top 10 Feature Importances by Position (Baseline RF)",
      subtitle = "Permutation importance: % increase in MSE when feature is permuted",
      x        = "% Increase in MSE",
      y        = NULL
    )
  
  ggsave(file.path(FIGURE_DIR, "03_feature_importance.png"),
         p_importance, width = 12, height = 8, dpi = 150)
}
p_importance
# --- 4. Predicted vs actual scatter plots -----------------------------------

r2_labels <- predictions %>%
  filter(model == "Baseline") %>%
  mutate(position_group = factor(position_group,
                                 levels = c("Forward","Midfielder","Defender"))) %>%
  group_by(position_group) %>%
  summarise(
    r2 = round(cor(actual, predicted)^2, 3),
    x  = min(actual) + 0.05 * (max(actual) - min(actual)),
    y  = max(predicted) * 0.90,
    .groups = "drop"
  )

p_pred_actual <- predictions %>%
  filter(model == "Baseline") %>%
  mutate(position_group = factor(position_group,
                                  levels = c("Forward","Midfielder","Defender"))) %>%
  ggplot(aes(x = actual, y = predicted, colour = position_group)) +
  geom_point(alpha = 0.35, size = 1.2, show.legend = FALSE) +
  geom_abline(slope = 1, intercept = 0,
              colour = "black", linetype = "dashed", linewidth = 0.8) +
  geom_text(data = r2_labels,
            aes(x = x, y = y, label = paste0("R² = ", r2)),
            inherit.aes = FALSE,
            fontface = "bold", size = 4, hjust = 0) +
  facet_wrap(~ position_group, scales = "free") +
  scale_colour_manual(values = c("Forward"    = "red",
                                  "Midfielder" = "blue",
                                  "Defender"   = "green")) +
  labs(
    title    = "Predicted vs Actual (Baseline Random Forest)",
    subtitle = "Dashed line = perfect prediction | Each dot = one player-season",
    x = "Actual (Season N+1 target)",
    y = "Predicted"
  )

ggsave("output/figures/04_predicted_vs_actual.png", p_pred_actual,
       width = 12, height = 5, dpi = 150)

ggsave(file.path(FIGURE_DIR, "04_predicted_vs_actual.png"), p_pred_actual, width = 12, height = 5, dpi = 150)
p_pred_actual
# --- 5. Year-on-year stability: target distribution by season pair ----------

p_stability <- longitudinal %>%
  mutate(
    season_pair    = paste0(season_n, "->", season_n1),
    position_group = factor(position_group,
                             levels = c("Forward","Midfielder","Defender"))
  ) %>%
  ggplot(aes(x = season_pair, y = target_next, fill = position_group)) +
  geom_boxplot(outlier.alpha = 0.2) +
  facet_wrap(~ position_group, scales = "free_y") +
  scale_fill_manual(values = c("Forward"    = "#E41A1C",
                                "Midfielder" = "#377EB8",
                                "Defender"   = "#4DAF4A")) +
  labs(
    title    = "Year-on-Year Target Stability",
    subtitle = "Distribution of season N+1 targets across consecutive season pairs",
    x = "Season Pair (N -> N+1)",
    y = "Target Value (per 90)"
  ) +
  theme(legend.position  = "none",
        axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("output/figures/05_year_on_year_stability.png", p_stability,
       width = 12, height = 6, dpi = 150)

ggsave(file.path(FIGURE_DIR, "05_year_on_year_stability.png"), p_stability, width = 12, height = 6, dpi = 150)
p_stability
# --- 6. RMSE and MAE comparison ---------------------------------------------

metrics_long <- results %>%
  select(position_group, model, rmse, mae) %>%
  pivot_longer(cols = c(rmse, mae), names_to = "metric", values_to = "value")

p_metrics <- metrics_long %>%
  ggplot(aes(x = position_group, y = value, fill = model)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  facet_wrap(~ metric, scales = "free_y", labeller = labeller(
    metric = c(rmse = "RMSE", mae = "MAE")
  )) +
  scale_fill_brewer(palette = "Set2", labels = c("Baseline", "Weka CFS", "R CFS")) +
  labs(
    title = "RMSE and MAE by Position and Model",
    x = "Position Group",
    y = "Error",
    fill = "Model"
  )

ggsave(file.path(FIGURE_DIR, "06_rmse_mae_comparison.png"), p_metrics, width = 12, height = 5, dpi = 150)
p_metrics


