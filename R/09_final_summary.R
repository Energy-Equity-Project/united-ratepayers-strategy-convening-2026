# Assemble the final United Ratepayers Convening 2026 summary.
#
# Joins CEO compensation, utility profits, energy burdens, and disconnections
# with residential customer counts from EIA 861 (electric) and EIA 176 PUDL
# (gas) into a single 12-row comparative table.
#
# Outputs:
#   outputs/<dd-mm-yyyy>-united-ratepayers-final-summary.csv
#   outputs/<dd-mm-yyyy>-united-ratepayers-final-summary.xlsx (formatted)

library(tidyverse)
library(glue)

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("Install openxlsx: install.packages('openxlsx')")
}

source("R/lib/target_subsidiaries.R")

# ---- 1. Helper: pick latest dated file matching a pattern -------------------

latest_output <- function(pattern) {
  matches <- list.files("outputs", pattern = pattern, full.names = TRUE)
  if (length(matches) == 0) stop("No output file matching ", pattern)
  sort(matches, decreasing = TRUE)[1]
}

# ---- 2. Load four pipeline outputs ------------------------------------------

ceo_path     <- latest_output("epi-exec-comp\\.csv$")
profits_path <- latest_output("epi-utility-profits\\.csv$")
shutoffs_path <- latest_output("united-ratepayers-shutoffs\\.csv$")
burdens_path <- latest_output("united-ratepayers-energy-burdens\\.csv$")

message("CEO comp:       ", ceo_path)
message("Profits:        ", profits_path)
message("Shutoffs:       ", shutoffs_path)
message("Burdens:        ", burdens_path)

ceo      <- read.csv(ceo_path, stringsAsFactors = FALSE)
profits  <- read.csv(profits_path, stringsAsFactors = FALSE)
shutoffs <- read.csv(shutoffs_path, stringsAsFactors = FALSE)
burdens  <- read.csv(burdens_path, stringsAsFactors = FALSE) %>%
  rename(target_utility = target_holding_co)

# ---- 3. EIA 861 residential electric customers (2024) -----------------------

eia_861_path <- "../../Cleaned_Data/eia/861/14-02-2026-eia-861-sales.csv"
message("EIA 861:        ", eia_861_path)

eia_861 <- read.csv(eia_861_path, stringsAsFactors = FALSE) %>%
  filter(year == 2024) %>%
  distinct(utility_number, state, .keep_all = TRUE)

target_utilities <- targets %>%
  distinct(target_holding_co) %>%
  pull(target_holding_co)

electric_customers <- map_dfr(target_utilities, function(target) {
  target_subs <- targets %>% filter(target_holding_co == target)
  combined_regex <- paste(target_subs$name_regex, collapse = "|")
  matched <- eia_861 %>%
    filter(str_detect(toupper(utility_name), combined_regex))
  tibble(
    target_utility = target,
    residential_electric_customers_2024 = sum(matched$residential_customers, na.rm = TRUE)
  )
})

# ---- 4. EIA 176 PUDL residential gas customers (2024) -----------------------

eia_176_path <- "../../Cleaned_Data/pudl/eia/176/25-05-2026-eia-176-pudl-2024.csv"
message("EIA 176 (PUDL): ", eia_176_path)

eia_176 <- read.csv(eia_176_path, stringsAsFactors = FALSE) %>%
  filter(customer_class == "residential")

# Gas-subsidiary mapping for combo IOUs that operate gas distribution.
# Verified against utility_name values in the PUDL EIA 176 2024 file.
# NV Energy gas comes through Sierra Pacific Power Co (Reno/Sparks LDC; Nevada Power is
# electric-only and Southwest Gas serves Las Vegas independently).
# BHE rollup adds MidAmerican Energy gas (IA primary, plus IL/NE/SD).
gas_targets <- tribble(
  ~target_utility,             ~gas_name_regex,
  "Duke Energy",               "^DUKE ENERGY OHIO$|^DUKE ENERGY KENTUCKY$|^PIEDMONT NATURAL GAS$",
  "Exelon",                    "^BGE$|^PECO ENERGY COMPANY$|^DELMARVA POWER AND LIGHT",
  "National Grid",             "BOSTON GAS CO DBA NATIONAL GRID|KEYSPAN ENERGY DBA NATIONAL GRID|NIAGARA MOHAWK DBA NATIONAL GRID|NARRAGANSETT ELECCO DBA RIENERGY",
  "PG&E",                      "^PACIFIC GAS$",
  "Xcel Energy",               "^NORTHERN STATES POWER COMPANY$|^PUB SERVICE CO OF COLORADO$",
  "Southern Company",          "^ATLANTA GAS LIGHT$|^NICOR GAS$|^VIRGINIA NAT GAS INC$|^CHATTANOOGA GAS CO$",
  "NV Energy",                 "^SIERRA PACIFIC POWER COMPANY$",
  "Berkshire Hathaway Energy", "^SIERRA PACIFIC POWER COMPANY$|^MIDAMERICAN ENERGY COMPANY$"
)

gas_customers <- map_dfr(target_utilities, function(target) {
  pattern_row <- gas_targets %>% filter(target_utility == target)
  if (nrow(pattern_row) == 0) {
    return(tibble(target_utility = target, residential_gas_customers_2024 = NA_real_))
  }
  matched <- eia_176 %>%
    filter(str_detect(toupper(utility_name), pattern_row$gas_name_regex))
  tibble(
    target_utility = target,
    residential_gas_customers_2024 = sum(matched$total_customers, na.rm = TRUE)
  )
})

# ---- 5. Assemble final table ------------------------------------------------

# Stable ordering by README target sequence
target_order <- c(
  "American Electric Power", "ComEd", "Duke Energy", "Exelon", "National Grid",
  "PG&E", "Xcel Energy", "Arizona Public Service", "El Paso Electric", "Southern Company",
  "NV Energy", "Berkshire Hathaway Energy"
)

# CEO pay rank is computed against the full EPI universe (all utility CEOs in
# EPI's 2025 dataset), not just the 10 target utilities. Dedupe by utility
# (incumbent = highest-paid row) to mirror 01_epi_exec_comp.R.
epi_universe <- read.csv("../../Data/epi/EPI_Exec_Comp_Data_2025.csv",
                         stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM") %>%
  janitor::clean_names() %>%
  group_by(utility) %>%
  slice_max(total_compensation, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(ceo_pay_rank = dense_rank(desc(total_compensation)))

epi_universe_n <- nrow(epi_universe)
message("EPI universe size (deduped utilities): ", epi_universe_n)

final_summary <- tibble(target_utility = target_order) %>%
  left_join(ceo %>% select(target_utility, ceo_name, ceo_total_compensation_usd = ceo_pay_usd),
            by = "target_utility") %>%
  left_join(
    epi_universe %>% select(name, ceo_pay_rank),
    by = c("ceo_name" = "name")
  ) %>%
  left_join(
    # Coerce 0 to NA — the EPI source uses 0 to mean "data unavailable" for
    # National Grid (UK fiscal year lag) and El Paso Electric (private since 2020).
    # Without this, 0-valued ratios produce a misleading -100% change.
    profits %>%
      transmute(
        target_utility,
        net_income_2025_millions = na_if(profit_2025_millions, 0),
        profit_change_2024_to_2025 = case_when(
          profit_ratio_2024_2025 == 0 | is.na(profit_ratio_2024_2025) ~ NA_real_,
          TRUE ~ profit_ratio_2024_2025 - 1
        ),
        profit_change_2021_to_2025 = case_when(
          profit_ratio_2021_2025 == 0 | is.na(profit_ratio_2021_2025) ~ NA_real_,
          TRUE ~ profit_ratio_2021_2025 - 1
        )
      ),
    by = "target_utility"
  ) %>%
  left_join(
    burdens %>%
      transmute(
        target_utility,
        weighted_mean_energy_burden = weighted_mean_burden,
        weighted_median_energy_burden = weighted_median_burden,
        pct_customers_above_6pct_burden = pct_hh_above_6pct
      ),
    by = "target_utility"
  ) %>%
  left_join(
    shutoffs %>%
      transmute(
        target_utility,
        # Sum across service types — script 03 already deduplicates the known
        # overlap rows (PECO and Xcel CO "Electric and Gas Combined Customers"),
        # so adding electric + combined here aggregates BHE's MidAmerican IL
        # ("Electric and Gas") with MidAmerican IA / PacifiCorp ("Electric")
        # without double-counting. For PG&E (combined-only) and most others
        # one term is zero so the sum reduces to a single bucket.
        residential_customers_disconnected = case_when(
          (electric_disconnections + combined_disconnections) > 0 ~
            electric_disconnections + combined_disconnections,
          TRUE ~ NA_real_
        ),
        # Parse "YYYY-YYYY" or "YYYY-YYYY" range — the trailing year is the
        # most recent year of EJL-reported disconnection data for the utility.
        disconnections_most_recent_year = suppressWarnings(
          as.integer(str_extract(year_range_used, "\\d{4}$"))
        ),
        disconnection_year_range = year_range_used
      ),
    by = "target_utility"
  ) %>%
  left_join(electric_customers, by = "target_utility") %>%
  left_join(gas_customers, by = "target_utility")

# ---- 6. Print summary -------------------------------------------------------

message("\n", strrep("=", 70))
message("UNITED RATEPAYERS 2026 — FINAL SUMMARY")
message(strrep("=", 70), "\n")

print(
  final_summary %>%
    mutate(
      ceo_total_compensation_usd = scales::dollar(ceo_total_compensation_usd, accuracy = 1),
      net_income_2025_millions   = scales::dollar(net_income_2025_millions, accuracy = 1),
      profit_change_2024_to_2025 = scales::percent(profit_change_2024_to_2025, accuracy = 0.1),
      profit_change_2021_to_2025 = scales::percent(profit_change_2021_to_2025, accuracy = 0.1),
      weighted_mean_energy_burden = scales::percent(weighted_mean_energy_burden, accuracy = 0.1),
      weighted_median_energy_burden = scales::percent(weighted_median_energy_burden, accuracy = 0.1),
      pct_customers_above_6pct_burden = scales::percent(pct_customers_above_6pct_burden, accuracy = 0.1),
      residential_customers_disconnected = scales::comma(residential_customers_disconnected),
      residential_electric_customers_2024 = scales::comma(residential_electric_customers_2024),
      residential_gas_customers_2024 = scales::comma(residential_gas_customers_2024)
    ),
  n = Inf, width = Inf
)

# ---- 7. Write CSV -----------------------------------------------------------

csv_path <- glue("outputs/{format(Sys.Date(), '%d-%m-%Y')}-united-ratepayers-final-summary.csv")
write.csv(final_summary, csv_path, row.names = FALSE)
message("\nCSV written to: ", csv_path)

# ---- 8. Write formatted Excel -----------------------------------------------

xlsx_path <- glue("outputs/{format(Sys.Date(), '%d-%m-%Y')}-united-ratepayers-final-summary.xlsx")

wb <- openxlsx::createWorkbook()

# --- Summary sheet ---
openxlsx::addWorksheet(wb, "Summary")

# Drop the full year-range helper column for the display sheet (footnote covers it);
# keep the parsed most-recent-year for at-a-glance context next to the disconnection count.
display <- final_summary %>%
  select(
    target_utility,
    ceo_name, ceo_total_compensation_usd, ceo_pay_rank,
    net_income_2025_millions, profit_change_2024_to_2025, profit_change_2021_to_2025,
    weighted_mean_energy_burden, weighted_median_energy_burden, pct_customers_above_6pct_burden,
    residential_customers_disconnected, disconnections_most_recent_year,
    residential_electric_customers_2024, residential_gas_customers_2024
  )

# Column-group header row (row 1) + column headers (row 2); data starts row 3
groups <- c(
  "Identity" = 1,
  "CEO compensation" = 3,
  "Net income (FY2025)" = 3,
  "Energy burdens" = 3,
  "Disconnections" = 2,
  "Customer counts (2024)" = 2
)
col_pos <- 1
header_style <- openxlsx::createStyle(textDecoration = "bold", halign = "center",
                                      border = "TopBottomLeftRight", fgFill = "#D9E1F2")
for (i in seq_along(groups)) {
  span <- groups[[i]]
  openxlsx::writeData(wb, "Summary", names(groups)[i], startCol = col_pos, startRow = 1)
  if (span > 1) {
    openxlsx::mergeCells(wb, "Summary", cols = col_pos:(col_pos + span - 1), rows = 1)
  }
  openxlsx::addStyle(wb, "Summary", header_style,
                     rows = 1, cols = col_pos:(col_pos + span - 1), gridExpand = TRUE)
  col_pos <- col_pos + span
}

openxlsx::writeData(wb, "Summary", display, startRow = 2, headerStyle = openxlsx::createStyle(
  textDecoration = "bold", border = "TopBottom", fgFill = "#F2F2F2"
))

# Number formats — data rows are 3 .. (3 + n - 1)
n_rows <- nrow(display)
data_rows <- 3:(2 + n_rows)

dollar_style    <- openxlsx::createStyle(numFmt = "$#,##0")
millions_style  <- openxlsx::createStyle(numFmt = "$#,##0.0\"M\"")
percent_style   <- openxlsx::createStyle(numFmt = "0.0%")
comma_style     <- openxlsx::createStyle(numFmt = "#,##0")
int_style       <- openxlsx::createStyle(numFmt = "0", halign = "center")

# Column positions in display:
# 1 target_utility | 2 ceo_name | 3 ceo_pay | 4 rank | 5 net_income |
# 6 profit_24_25 | 7 profit_21_25 | 8 mean_burden | 9 median_burden |
# 10 pct_above_6 | 11 disconnections | 12 disconnect_year | 13 electric_cust | 14 gas_cust
openxlsx::addStyle(wb, "Summary", dollar_style,   rows = data_rows, cols = 3)
openxlsx::addStyle(wb, "Summary", int_style,      rows = data_rows, cols = 4)
openxlsx::addStyle(wb, "Summary", millions_style, rows = data_rows, cols = 5)
openxlsx::addStyle(wb, "Summary", percent_style,  rows = data_rows, cols = 6:10, gridExpand = TRUE)
openxlsx::addStyle(wb, "Summary", comma_style,    rows = data_rows, cols = 11)
openxlsx::addStyle(wb, "Summary", int_style,      rows = data_rows, cols = 12)
openxlsx::addStyle(wb, "Summary", comma_style,    rows = data_rows, cols = 13:14, gridExpand = TRUE)

openxlsx::freezePane(wb, "Summary", firstActiveRow = 3, firstActiveCol = 2)
openxlsx::setColWidths(wb, "Summary", cols = 1:ncol(display), widths = "auto")

# --- Methodology sheet ---
openxlsx::addWorksheet(wb, "Methodology")
methodology <- c(
  "United Ratepayers Strategy Convening 2026 — Final Summary",
  "Prepared by Energy Equity Project for People's Action Institute",
  paste0("Generated: ", format(Sys.Date(), "%B %d, %Y")),
  "",
  "Sources and definitions",
  "",
  "Target utility — Twelve investor-owned utilities defined in the project README. NV Energy is modeled as an operating subsidiary of Berkshire Hathaway Energy (CEO comp shown at the BHE parent level via Gregory Abel — mirrors the APS / Pinnacle West precedent); Berkshire Hathaway Energy itself is a holding-company target whose financials roll up Nevada Power + Sierra Pacific Power + PacifiCorp + MidAmerican Energy (mirrors the Exelon multi-sub rollup pattern).",
  "",
  "CEO compensation — Most recent proxy-year total compensation from SEC DEF 14A filings via the EPI Executive Compensation database. Source: 24-05-2026-epi-exec-comp.csv. National Grid (UK-listed) and El Paso Electric (private since 2020) do not file US proxy statements, so values are NA.",
  "",
  paste0("CEO pay rank — Dense rank descending across the full EPI 2025 executive-compensation dataset (", epi_universe_n, " utilities after deduplication, keeping the highest-paid named executive per utility as the incumbent). Lower number = higher pay. NAs preserved as NA rank for utilities not in EPI (National Grid, APS, El Paso Electric)."),
  "",
  "Net income (FY2025) — Sum of US operating-subsidiary net income for the most recently reported fiscal year. Source: 24-05-2026-epi-utility-profits.csv. El Paso Electric and National Grid have limited public disclosures and may be NA.",
  "",
  "Profit change — Computed as (FY2025 net income / FY base year net income) - 1. The 2021→2025 metric captures multi-year growth; the 2024→2025 metric captures most-recent-year change.",
  "",
  "Energy burdens — Service-territory-weighted residential energy burden derived from DOE LEAD (2022) tract-level cost and income, projected to 2024 using ACS B19013 income growth and BLS CPI energy components. Aggregated via the utility-tract crosswalk built from HIFLD service territories. Source: 26-05-2026-united-ratepayers-energy-burdens.csv. See methodology.md for full projection details.",
  "",
  "% customers above 6% burden — Share of households in the service territory with total annual energy cost above 6% of household income (the conventional affordability threshold).",
  "",
  "Residential customers disconnected — Annual residential disconnections for non-payment, summed across operating subsidiaries reporting to the Energy Justice Lab disconnections dashboard. Year coverage varies by utility (2021-2024); APS and El Paso Electric reflect 2022 only. Six AEP/Exelon/Southern subsidiaries do not report to EJL and are excluded. Source: 24-05-2026-united-ratepayers-shutoffs.csv.",
  "",
  "Disconnections most recent year — Trailing year of the EJL year_range_used field for each utility. Indicates the most recent reporting year reflected in the disconnections total; values lower than 2024 signal the utility's data has not been refreshed in EJL since that year.",
  "",
  "Residential electric customers (2024) — Sum of EIA Form 861 reported residential customer counts across each utility's operating subsidiaries, deduplicated by (utility_number, state). Source: Cleaned_Data/eia/861/14-02-2026-eia-861-sales.csv. Caveat: in states with Community Choice Aggregation (notably California), EIA 861 may assign generation customers to the CCA, so PG&E's reported residential count reflects bundled-service customers only and understates total accounts in its delivery territory by roughly 3M.",
  "",
  "Residential gas customers (2024) — Sum of EIA Form 176 (PUDL/Zenodo) residential total_customers across each utility's gas operating subsidiaries. NA for electric-only IOUs (AEP, ComEd standalone, APS, El Paso). National Grid includes Narragansett (RI), now PPL-owned as of May 2022, for consistency with the project's existing subsidiary mapping. Source: Cleaned_Data/pudl/eia/176/25-05-2026-eia-176-pudl-2024.csv."
)
openxlsx::writeData(wb, "Methodology", methodology)
openxlsx::setColWidths(wb, "Methodology", cols = 1, widths = 120)
openxlsx::addStyle(wb, "Methodology", openxlsx::createStyle(textDecoration = "bold", fontSize = 14),
                   rows = 1, cols = 1)
openxlsx::addStyle(wb, "Methodology", openxlsx::createStyle(textDecoration = "bold"),
                   rows = 5, cols = 1)

openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)
message("Excel written to: ", xlsx_path)
