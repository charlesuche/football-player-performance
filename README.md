# Player Valuation in European Football — Revisited

**TDDE64 Research Project | Linköping University**

Extension of Nsolo, Lambrix & Carlsson (2018) with longitudinal multi-season analysis, per-90 normalisation, and advanced defensive metrics across the Big-Five European leagues (2017/18–2023/24).

## Research Questions

1. Does per-90 normalisation improve prediction over raw counts?
2. Does the defensive composite (`def_actions_p90`) enable meaningful defender prediction?
3. Which feature selection method (Weka vs R CFS) produces better model performance?
4. Does the position predictability ordering from Nsolo (forwards best, defenders worst) hold?
5. Can a small CFS-selected feature subset match the full-feature baseline?

## Quick Start

```r
# 1. Set working directory to this project folder
setwd("/path/to/player_value")

# 2. Install packages (once)
source("install_packages.R")

# 3. Run full pipeline
source("run_analysis.R")
```

Or run scripts individually in order (`scripts/01_` through `scripts/07_`).

## Project Structure

```
player_value/
├── install_packages.R      # One-time package installation
├── run_analysis.R          # Master script (runs all steps)
├── R/
│   └── utils.R             # Shared helpers (CFS, standardisation, metrics)
├── scripts/
│   ├── 01_collect_data.R       # Download FBref data via worldfootballR
│   ├── 02_clean_data.R         # Clean, filter, handle transfers
│   ├── 03_feature_engineering.R # Composites + longitudinal pairs
│   ├── 04_cfs_selection.R      # R implementation of Weka CFS
│   ├── 05_modeling.R           # Random Forest models
│   ├── 06_visualize.R          # Figures
│   ├── 07_export_weka.R        # ARFF export for Weka validation
│   └── 08_discussion.R         # Auto-generated discussion vs Nsolo limitations
├── data/
│   ├── raw/                # Downloaded stat tables (RDS)
│   └── processed/          # Cleaned data, features, model objects
└── output/
    ├── tables/             # CSV results (model metrics, importance)
    ├── figures/            # PNG visualisations
    └── weka/               # ARFF files + Weka instructions
```

## Methodology Summary

| Step | Description |
|------|-------------|
| **Data** | FBref Big-5 leagues, seasons 2018–2024 (7 seasons), via `worldfootballR` |
| **Filter** | ≥450 min/season (collection), ≥900 min in both seasons (longitudinal) |
| **Transfers** | Minutes-weighted average of per-90 stats across clubs |
| **Design** | Season N features → predict Season N+1 target (consecutive seasons only) |
| **Targets** | FW/MF: `xgc_p90` (xG+xAG per 90); DF: `def_actions_p90` |
| **Feature selection** | CFS: \|r\| ≥ 0.10 with target; inter-feature \|r\| ≤ 0.80 |
| **Model** | Random Forest (ntree=500, mtry=√p), 80/20 split, position-specific |
| **Evaluation** | R², RMSE, MAE, permutation importance |

## Weka Validation (Model A)

After the pipeline runs:

1. Open ARFF files in `output/weka/` using Weka 3.x
2. Run `AttributeSelectedClassifier` with `CfsSubsetEval` + `BestFirst`
3. Record selected features in `output/weka/weka_selected_features.csv`
4. Re-run `scripts/05_modeling.R` and `scripts/06_visualize.R`

See `output/weka/WEA_INSTRUCTIONS.txt` for detailed steps.

## Key Outputs

- `output/tables/model_results.csv` — R², RMSE, MAE for Baseline / Weka CFS / R CFS
- `output/tables/feature_importance.csv` — Permutation importance per model
- `output/tables/cfs_r_selected_features.csv` — R CFS selected features
- `output/figures/01_r2_comparison.png` — Main results figure
- `output/discussion_summary.md` — Discussion addressing Nsolo's four limitations

## Discussion: Addressing Nsolo's Four Limitations

| Nsolo Limitation | This Extension |
|------------------|----------------|
| Single season only | 7-season longitudinal year-on-year prediction |
| Raw counting stats | All features per-90 normalised |
| Defenders poorly predicted | `def_actions_p90` composite + advanced defensive metrics |
| Game stats only | Framework ready for market value / salary extensions |

## Reference

Nsolo, E., Lambrix, P., & Carlsson, L. (2018). Player Valuation in European Football. In: Brefeld U. et al. (eds) Machine Learning and Data Mining for Sports Analytics. MLSA 2018. LNCS vol 11330, pp 42–54. Springer, Cham.

## Requirements

- R ≥ 4.0
- Packages: `worldfootballR`, `tidyverse`, `randomForest`, `caret`, `janitor`, `ggplot2`
- Weka 3.x (optional, for Model A validation)
