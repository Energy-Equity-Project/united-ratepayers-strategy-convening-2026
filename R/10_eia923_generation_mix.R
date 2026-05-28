# Power generation mix by target utility (EIA-923, calendar year 2025).
#
# Companion deliverable to the main final-summary table — describes the
# fuel/technology mix behind the power each target IOU generates.
#
# Source: Cleaned EIA Form 923 Schedule 5 (Page 1 Generation and Fuel Data),
# aggregated to operator x fuel x metric x month.
#   ../../Cleaned_Data/eia/923/<dd-mm-yyyy>-eia-923-plant-operations.csv
#
# Metric: net_generation_mwh only. Other consumption_types are either input-side
# (heat content, fuel consumption) or expressed in fuel-specific physical units
# (short tons / Mcf / barrels) that are not comparable across fuel types and are
# NA for renewables / nuclear. MWh sidesteps the unit-mismatch problem entirely.
#
# Output: one xlsx with three sheets (4-group / 9-group / 18-code) covering all
# 12 target holding companies. T&D-only subsidiaries are reported with 0 / NA
# generation, which is a real coverage gap (the utility owns no generation),
# not a data-matching failure.

library(tidyverse)
library(glue)

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Install openxlsx: install.packages('openxlsx')")
}

source("R/lib/target_subsidiaries.R")

# ---- 1. Helper: pick latest dated EIA-923 cleaned file ----------------------

latest_eia923 <- function() {
  dir <- "../../Cleaned_Data/eia/923"
  matches <- list.files(dir, pattern = "eia-923-plant-operations\\.csv$", full.names = TRUE)
  if (length(matches) == 0) stop("No EIA-923 cleaned file found in ", dir)
  sort(matches, decreasing = TRUE)[1]
}

eia923_path <- latest_eia923()
message("EIA-923 input: ", eia923_path)

# ---- 2. Load and filter to net generation only ------------------------------

eia923 <- read.csv(eia923_path, stringsAsFactors = FALSE) %>%
  filter(consumption_type == "net_generation_mwh")

# Annual rollup: sum across the 12 months per operator x fuel.
# Keep negative values (pumped-storage parasitic load is real).
annual <- eia923 %>%
  group_by(operator_id, operator_name, fuel_type) %>%
  summarise(net_generation_mwh = sum(amount, na.rm = TRUE)) %>%
  ungroup()

# ---- 3. Fuel-group lookup tables (4 / 9 / 18) -------------------------------
# Source: EIA-923 documentation, MER fuel-type codes.
# HPS (pumped storage) is grouped with hydro / renewables for consistency with
# the 9-group hydro bucket; the methodology document flags this nuance.

fuel_groups <- tribble(
  ~fuel_type, ~fuel_label_18,                              ~group_9,                       ~group_4,
  "NUC",      "Nuclear",                                   "Nuclear",                      "Nuclear",
  "COL",      "Coal",                                      "Coal",                         "Fossil fuels",
  "WOC",      "Waste coal",                                "Coal",                         "Fossil fuels",
  "NG",       "Natural gas",                               "Natural gas",                  "Fossil fuels",
  "OOG",      "Other gases",                               "Natural gas",                  "Fossil fuels",
  "DFO",      "Distillate fuel oil",                       "Petroleum",                    "Fossil fuels",
  "RFO",      "Residual fuel oil",                         "Petroleum",                    "Fossil fuels",
  "WOO",      "Waste oil",                                 "Petroleum",                    "Fossil fuels",
  "PC",       "Petroleum coke",                            "Petroleum",                    "Fossil fuels",
  "SUN",      "Solar",                                     "Solar",                        "Renewables",
  "WND",      "Wind",                                      "Wind",                         "Renewables",
  "HYC",      "Hydroelectric, conventional",               "Hydro",                        "Renewables",
  "HPS",      "Hydroelectric, pumped storage",             "Hydro",                        "Renewables",
  "GEO",      "Geothermal",                                "Geothermal",                   "Renewables",
  "WWW",      "Wood and wood waste",                       "Biomass / Other renewables",   "Renewables",
  "MLG",      "Biogenic MSW and landfill gas",             "Biomass / Other renewables",   "Renewables",
  "ORW",      "Other renewables",                          "Biomass / Other renewables",   "Renewables",
  "OTH",      "Other",                                     "Other",                        "Other"
)

# Sanity check: every fuel_type appearing in the data must map.
unmapped <- annual %>% anti_join(fuel_groups, by = "fuel_type") %>% distinct(fuel_type)
if (nrow(unmapped) > 0) {
  stop("Unmapped fuel_type codes in EIA-923: ", paste(unmapped$fuel_type, collapse = ", "))
}

annual_mapped <- annual %>% left_join(fuel_groups, by = "fuel_type")

# ---- 4. Match operators to target holding companies -------------------------
# For each target_holding_co, build a single combined regex from its
# subsidiary name_regex values and match against operator_name.
#
# Known false positives produced by the shared name_regex against EIA-923
# operator strings (the regex was tuned for HIFLD / EIA-861 / EJL names):
#   - "Liberty Utilities (CalPeco Electric) LLC" matches Exelon's "PECO"
#     pattern via the CalPeco substring; it is an Algonquin Power subsidiary
#     in CA/NV with no Exelon affiliation.
#   - "Western Massachusetts Electric Company" matches National Grid's
#     "MASSACHUSETTS ELECTRIC" pattern; it is an Eversource subsidiary, not
#     a National Grid subsidiary.
known_false_positives <- c(
  "Liberty Utilities (CalPeco Electric) LLC",
  "Western Massachusetts Electric Company"
)

target_order <- c(
  "American Electric Power", "ComEd", "Duke Energy", "Exelon", "National Grid",
  "PG&E", "Xcel Energy", "Arizona Public Service", "El Paso Electric", "Southern Company",
  "NV Energy", "Berkshire Hathaway Energy"
)

operator_target_map <- map_dfr(target_order, function(target) {
  subs <- targets %>% filter(target_holding_co == target)
  combined_regex <- paste(subs$name_regex, collapse = "|")
  matched_ops <- annual_mapped %>%
    filter(str_detect(toupper(operator_name), combined_regex)) %>%
    filter(!operator_name %in% known_false_positives) %>%
    distinct(operator_id, operator_name)
  if (nrow(matched_ops) == 0) {
    return(tibble(target_holding_co = target,
                  operator_id = NA_integer_, operator_name = NA_character_))
  }
  matched_ops %>% mutate(target_holding_co = target)
})

# Audit log
message("\nOperator matches by target:")
for (target in target_order) {
  ops <- operator_target_map %>% filter(target_holding_co == target, !is.na(operator_id))
  message("  ", target, " - ", nrow(ops), " operator(s)")
  if (nrow(ops) > 0) {
    walk(sort(unique(ops$operator_name)), ~ message("    \u2022 ", .x))
  }
}

# Join in generation rows for each matched operator (overlapping rows preserved:
# ComEd operators roll up under both ComEd and Exelon; NV Energy operators roll
# up under both NV Energy and BHE — same pattern as the rest of the pipeline).
target_generation <- operator_target_map %>%
  filter(!is.na(operator_id)) %>%
  inner_join(annual_mapped, by = c("operator_id", "operator_name"),
             relationship = "many-to-many")

# ---- 5. Build pivoted tables (one per tier) ---------------------------------
# Each tier table is one row per target_holding_co. Columns alternate between
# MWh and % of utility total per fuel group, with a leading total-MWh column.

build_tier_table <- function(df, group_col, group_order) {
  totals <- df %>%
    group_by(target_holding_co) %>%
    summarise(total_mwh = sum(net_generation_mwh, na.rm = TRUE)) %>%
    ungroup()

  per_group <- df %>%
    group_by(target_holding_co, !!sym(group_col)) %>%
    summarise(mwh = sum(net_generation_mwh, na.rm = TRUE)) %>%
    ungroup() %>%
    left_join(totals, by = "target_holding_co") %>%
    mutate(pct = case_when(
      total_mwh > 0 ~ mwh / total_mwh,
      TRUE          ~ NA_real_
    ))

  mwh_wide <- per_group %>%
    select(target_holding_co, !!sym(group_col), mwh) %>%
    pivot_wider(names_from = !!sym(group_col), values_from = mwh, values_fill = 0)

  pct_wide <- per_group %>%
    select(target_holding_co, !!sym(group_col), pct) %>%
    pivot_wider(names_from = !!sym(group_col), values_from = pct, values_fill = 0)

  # Interleave MWh and % columns in the requested group_order.
  base <- tibble(target_holding_co = target_order) %>%
    left_join(totals, by = "target_holding_co") %>%
    mutate(total_mwh = replace_na(total_mwh, 0))

  for (g in group_order) {
    mwh_col <- if (g %in% names(mwh_wide)) mwh_wide[[g]][match(base$target_holding_co, mwh_wide$target_holding_co)] else 0
    pct_col <- if (g %in% names(pct_wide)) pct_wide[[g]][match(base$target_holding_co, pct_wide$target_holding_co)] else 0
    mwh_col[is.na(mwh_col)] <- 0
    pct_col[is.na(pct_col)] <- 0
    base[[paste0(g, " (MWh)")]] <- mwh_col
    base[[paste0(g, " (% of total)")]] <- pct_col
  }

  base
}

order_4  <- c("Fossil fuels", "Nuclear", "Renewables", "Other")
order_9  <- c("Nuclear", "Coal", "Natural gas", "Petroleum",
              "Solar", "Wind", "Hydro", "Geothermal",
              "Biomass / Other renewables", "Other")
order_18 <- fuel_groups$fuel_label_18

tier_4  <- build_tier_table(target_generation, "group_4",       order_4)
tier_9  <- build_tier_table(target_generation, "group_9",       order_9)
tier_18 <- build_tier_table(target_generation, "fuel_label_18", order_18)

# ---- 6. Console summary -----------------------------------------------------

utilities_with_generation <- tier_4 %>%
  filter(total_mwh > 0) %>%
  pull(target_holding_co)

n_with    <- length(utilities_with_generation)
n_without <- length(target_order) - n_with

message("\n", strrep("=", 70))
message("UNITED RATEPAYERS 2026 - EIA-923 GENERATION MIX")
message(strrep("=", 70))
message(n_with, "/12 utilities had EIA-923 generation. ",
        n_without, " had no reported generation (T&D-only).")
message("Total MWh across matched operators: ",
        scales::comma(sum(tier_4$total_mwh)))

# ---- 7. Write xlsx workbook -------------------------------------------------

xlsx_path <- glue("outputs/{format(Sys.Date(), '%d-%m-%Y')}-united-ratepayers-generation-mix.xlsx")

wb <- openxlsx::createWorkbook()

# Header styles
group_header_style <- openxlsx::createStyle(
  textDecoration = "bold", halign = "center",
  border = "TopBottomLeftRight", fgFill = "#D9E1F2"
)
col_header_style <- openxlsx::createStyle(
  textDecoration = "bold", border = "TopBottom", fgFill = "#F2F2F2",
  halign = "center", wrapText = TRUE
)
mwh_style    <- openxlsx::createStyle(numFmt = "#,##0")
pct_style    <- openxlsx::createStyle(numFmt = "0.0%")
total_style  <- openxlsx::createStyle(numFmt = "#,##0", textDecoration = "bold")

# Build one sheet per tier. Each sheet layout:
#   Row 1: column-group header band ("Net generation (MWh)" / "% of utility total")
#          spanning the paired columns for each fuel group
#   Row 2: column names (target_holding_co, total_mwh, then alternating MWh / %)
#   Row 3+: data
write_tier_sheet <- function(sheet_name, tbl, group_order) {
  openxlsx::addWorksheet(wb, sheet_name)

  # Row 1 — top group-header band. Columns 1-2 are Identity / Total; pairs follow.
  openxlsx::writeData(wb, sheet_name, "Utility", startCol = 1, startRow = 1)
  openxlsx::mergeCells(wb, sheet_name, cols = 1, rows = 1:2)
  openxlsx::writeData(wb, sheet_name, "Total net generation (MWh)",
                      startCol = 2, startRow = 1)
  openxlsx::mergeCells(wb, sheet_name, cols = 2, rows = 1:2)

  col_pos <- 3
  for (g in group_order) {
    openxlsx::writeData(wb, sheet_name, g, startCol = col_pos, startRow = 1)
    openxlsx::mergeCells(wb, sheet_name, cols = col_pos:(col_pos + 1), rows = 1)
    openxlsx::addStyle(wb, sheet_name, group_header_style,
                       rows = 1, cols = col_pos:(col_pos + 1), gridExpand = TRUE)
    col_pos <- col_pos + 2
  }
  openxlsx::addStyle(wb, sheet_name, group_header_style,
                     rows = 1:2, cols = 1:2, gridExpand = TRUE)

  # Row 2 — column names
  col_names <- c("Utility", "Total MWh")
  for (g in group_order) {
    col_names <- c(col_names, "MWh", "% of total")
  }
  for (j in seq_along(col_names)) {
    openxlsx::writeData(wb, sheet_name, col_names[j], startCol = j, startRow = 2)
  }
  openxlsx::addStyle(wb, sheet_name, col_header_style,
                     rows = 2, cols = seq_along(col_names), gridExpand = TRUE)

  # Row 3+ — data
  openxlsx::writeData(wb, sheet_name, tbl, startRow = 3, colNames = FALSE)

  n_rows    <- nrow(tbl)
  data_rows <- 3:(2 + n_rows)

  # Total-MWh column (col 2): bold comma
  openxlsx::addStyle(wb, sheet_name, total_style,
                     rows = data_rows, cols = 2, gridExpand = TRUE)

  # Alternating MWh / % columns starting at col 3
  col_pos <- 3
  for (g in group_order) {
    openxlsx::addStyle(wb, sheet_name, mwh_style,
                       rows = data_rows, cols = col_pos, gridExpand = TRUE)
    openxlsx::addStyle(wb, sheet_name, pct_style,
                       rows = data_rows, cols = col_pos + 1, gridExpand = TRUE)
    col_pos <- col_pos + 2
  }

  openxlsx::freezePane(wb, sheet_name, firstActiveRow = 3, firstActiveCol = 2)
  openxlsx::setColWidths(wb, sheet_name, cols = 1, widths = 28)
  openxlsx::setColWidths(wb, sheet_name, cols = 2:length(col_names), widths = 14)
}

write_tier_sheet("Summary - 4 Groups", tier_4,  order_4)
write_tier_sheet("Detail - 9 Groups",  tier_9,  order_9)
write_tier_sheet("Detail - 18 Codes",  tier_18, order_18)

openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)
message("\nXLSX written to: ", xlsx_path)
