# Aggregate 2024-projected tract-level energy burdens to per-target statistics.
#
# For each target_holding_co (10 rows):
#   - Weighted mean burden: each cost component weighted by its own valid-units
#     count, then divided by weighted income
#   - Weighted median burden: row-level burden weighted by hincp_valid_units
#   - Share of households above 6% burden threshold
#
# Inputs:
#   outputs/<latest>-utility-tract-burden-2024-detail.csv  (from 07_burden_estimates_2024.R)
#
# Output:
#   outputs/<dd-mm-yyyy>-united-ratepayers-energy-burdens.csv
#   One row per target_holding_co

library(tidyverse)
library(matrixStats)
library(glue)

# ---- 1. Load detail file (most recent) --------------------------------------

detail_files <- list.files("outputs", pattern = "utility-tract-burden-2024-detail\\.csv$",
                           full.names = TRUE)
if (length(detail_files) == 0) {
  stop("No detail file found in outputs/. Run 07_burden_estimates_2024.R first.")
}
detail_path <- sort(detail_files, decreasing = TRUE)[1]
message("Loading detail file: ", detail_path)

detail <- read.csv(detail_path, stringsAsFactors = FALSE)

message("Rows loaded: ", nrow(detail))
message("Targets: ", n_distinct(detail$target_holding_co))

# ---- 2. Per-target aggregation ----------------------------------------------

message("Aggregating per target_holding_co...")

summarize_target <- function(df) {
  df <- df %>% filter(!is.na(row_burden_2024))

  if (nrow(df) == 0) {
    return(tibble(
      n_tracts             = 0L,
      wt_electricity_cost_2024 = NA_real_,
      wt_gas_cost_2024         = NA_real_,
      wt_other_fuel_cost_2024  = NA_real_,
      wt_income_2024           = NA_real_,
      weighted_mean_burden     = NA_real_,
      weighted_median_burden   = NA_real_,
      n_hh_above_6pct          = NA_real_,
      n_hh_total               = NA_real_,
      pct_hh_above_6pct        = NA_real_
    ))
  }

  # Weighted mean components — each weighted by its own valid-units count
  wt_electricity <- sum(df$electricity_2024 * df$elep_valid_units, na.rm = TRUE) /
    sum(df$elep_valid_units, na.rm = TRUE)

  wt_gas <- sum(df$gas_2024 * df$gasp_valid_units, na.rm = TRUE) /
    sum(df$gasp_valid_units, na.rm = TRUE)

  wt_other <- sum(df$other_fuel_2024 * df$fulp_valid_units, na.rm = TRUE) /
    sum(df$fulp_valid_units, na.rm = TRUE)

  wt_income <- sum(df$income_2024 * df$hincp_valid_units, na.rm = TRUE) /
    sum(df$hincp_valid_units, na.rm = TRUE)

  weighted_mean_burden <- (wt_electricity + wt_gas + wt_other) / wt_income

  # Weighted median — row-level burden weighted by hincp_valid_units
  valid_rows <- !is.na(df$row_burden_2024) & !is.na(df$hincp_valid_units) &
    df$hincp_valid_units > 0
  weighted_median_burden <- weightedMedian(
    df$row_burden_2024[valid_rows],
    w = df$hincp_valid_units[valid_rows],
    na.rm = TRUE
  )

  # Households above 6% threshold
  n_hh_above_6pct <- sum(
    df$hincp_valid_units[!is.na(df$row_burden_2024) & df$row_burden_2024 > 0.06],
    na.rm = TRUE
  )
  n_hh_total <- sum(df$hincp_valid_units, na.rm = TRUE)
  pct_hh_above_6pct <- n_hh_above_6pct / n_hh_total

  tibble(
    n_tracts                 = n_distinct(df$tract_geoid),
    wt_electricity_cost_2024 = wt_electricity,
    wt_gas_cost_2024         = wt_gas,
    wt_other_fuel_cost_2024  = wt_other,
    wt_income_2024           = wt_income,
    weighted_mean_burden     = weighted_mean_burden,
    weighted_median_burden   = weighted_median_burden,
    n_hh_above_6pct          = n_hh_above_6pct,
    n_hh_total               = n_hh_total,
    pct_hh_above_6pct        = pct_hh_above_6pct
  )
}

burden_summary <- detail %>%
  group_by(target_holding_co) %>%
  group_modify(~ summarize_target(.x)) %>%
  ungroup() %>%
  arrange(target_holding_co)

# ---- 3. Print results -------------------------------------------------------

message("\n", strrep("=", 70))
message("ENERGY BURDEN SUMMARY — 2024 PROJECTED")
message(strrep("=", 70), "\n")

print(
  burden_summary %>%
    select(
      target_holding_co, n_tracts,
      wt_electricity_cost_2024, wt_gas_cost_2024,
      wt_income_2024, weighted_mean_burden, weighted_median_burden,
      pct_hh_above_6pct
    ) %>%
    mutate(
      weighted_mean_burden  = scales::percent(weighted_mean_burden,  accuracy = 0.1),
      weighted_median_burden = scales::percent(weighted_median_burden, accuracy = 0.1),
      pct_hh_above_6pct     = scales::percent(pct_hh_above_6pct,     accuracy = 0.1),
      wt_electricity_cost_2024 = scales::dollar(wt_electricity_cost_2024, accuracy = 1),
      wt_gas_cost_2024         = scales::dollar(wt_gas_cost_2024,         accuracy = 1),
      wt_income_2024           = scales::dollar(wt_income_2024,           accuracy = 1)
    ),
  n = Inf
)

# ---- 4. Write output --------------------------------------------------------

out_path <- glue("outputs/{format(Sys.Date(), '%d-%m-%Y')}-united-ratepayers-energy-burdens.csv")
write.csv(burden_summary, out_path, row.names = FALSE)
message("\nBurden summary written to: ", out_path)
