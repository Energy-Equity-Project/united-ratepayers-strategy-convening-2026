# Forward-project DOE LEAD 2022 tract-level energy burdens to 2024.
#
# Three growth ratios are applied:
#   - Income:      ACS B19013 tract median income 2022 → 2024
#   - Electricity: EIA 861 residential bill per customer (utility × state) 2022 → 2024
#   - Gas:         EIA 176 state avg residential gas bill 2022 → 2024
#   - Other fuel:  held at 2022 value (no ratio source available — understates burden
#                  slightly in tracts with significant heating-oil/propane/wood usage)
#
# Inputs:
#   Crosswalk  : outputs/<latest>-utility-tract-crosswalk.csv
#   ACS B19013 : ../../Data/us_census/acs/{2022,2024}/tract/B19013_[state].csv
#   EIA 861    : ../../Cleaned_Data/eia/861/14-02-2026-eia-861-sales.csv
#   EIA 176    : ../../Cleaned_Data/eia/176/15-04-2026-eia-176-residential-natural-gas.csv
#   DOE LEAD   : ../../Cleaned_Data/doe/lead/[state]-census_tract-lead-2022.csv
#
# Output:
#   outputs/<dd-mm-yyyy>-utility-tract-burden-2024-detail.csv
#   One row per target_holding_co × tract × DOE LEAD subpopulation

library(tidyverse)
library(glue)
library(janitor)

source("R/lib/target_subsidiaries.R")

# ---- 0. Configuration -------------------------------------------------------

acs_base   <- "../../Data/us_census/acs"
eia861_path <- "../../Cleaned_Data/eia/861/14-02-2026-eia-861-sales.csv"
eia176_path <- "../../Cleaned_Data/eia/176/15-04-2026-eia-176-residential-natural-gas.csv"
lead_dir    <- "../../Cleaned_Data/doe/lead"

target_states <- c(
  "AL", "AR", "AZ", "CA", "CO", "DC", "DE", "FL", "GA", "IA",
  "ID", "IL", "IN", "KY", "LA", "MA", "MD", "MI", "MN", "MS",
  "NC", "ND", "NE", "NJ", "NM", "NV", "NY", "OH", "OK", "OR",
  "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VA", "WA", "WI",
  "WV", "WY"
)

# ---- 1. Load crosswalk (most recent file) ------------------------------------

crosswalk_files <- list.files("outputs", pattern = "utility-tract-crosswalk\\.csv$", full.names = TRUE)
if (length(crosswalk_files) == 0) stop("No crosswalk file found in outputs/. Run 06_utility_tract_crosswalk.R first.")
crosswalk_path  <- sort(crosswalk_files, decreasing = TRUE)[1]
message("Loading crosswalk: ", crosswalk_path)

# Pad tract_geoid to 11 chars — the census shapefile drops leading zeros for
# states whose FIPS start with 0 (CA=06, AZ=04, etc.). DOE LEAD fips have the
# same issue and are padded to 11 below; both sides must match.
crosswalk <- read.csv(crosswalk_path, stringsAsFactors = FALSE) %>%
  mutate(tract_geoid = str_pad(as.character(tract_geoid), width = 11, side = "left", pad = "0"))

# ---- 2. Income ratio per tract (ACS B19013 2022 → 2024) ---------------------

message("Computing income ratios from ACS B19013...")

read_acs_state <- function(year, state) {
  path <- file.path(acs_base, year, "tract", glue("B19013_{state}.csv"))
  if (!file.exists(path)) {
    warning("ACS file not found: ", path)
    return(NULL)
  }
  read.csv(path, stringsAsFactors = FALSE) %>%
    select(GEOID, estimate) %>%
    mutate(
      GEOID    = str_pad(as.character(GEOID), width = 11, side = "left", pad = "0"),
      estimate = as.numeric(estimate),
      year     = as.integer(year)
    )
}

acs_all <- map_dfr(target_states, function(st) {
  bind_rows(
    read_acs_state(2022, st),
    read_acs_state(2024, st)
  )
}) %>%
  filter(!is.na(estimate), estimate > 0)

income_ratios <- acs_all %>%
  pivot_wider(names_from = year, values_from = estimate, names_prefix = "income_") %>%
  filter(!is.na(income_2022), !is.na(income_2024), income_2022 > 0) %>%
  mutate(income_ratio = income_2024 / income_2022) %>%
  select(GEOID, income_ratio)

message("  Income ratios computed for ", nrow(income_ratios), " tracts")

# ---- 3. Electric cost ratio per subsidiary × state (EIA 861) ----------------
#
# Match EIA 861 utility_name strings to each target subsidiary using the same
# holding-company approach as 03_ejl_disconnections.R, extended to cover all
# subsidiaries in the targets tibble.

message("Computing electricity cost ratios from EIA 861...")

eia861 <- read.csv(eia861_path, stringsAsFactors = FALSE) %>%
  filter(year %in% c(2022, 2024)) %>%
  mutate(
    utility_name = toupper(utility_name),
    state        = toupper(state)
  )

# Subsidiary → EIA 861 utility_name lookup
# Pattern: match the operating subsidiary's core name within EIA 861 utility_name
subsidiary_eia_patterns <- tribble(
  ~subsidiary_label,                  ~eia_pattern,
  "Appalachian Power",                "APPALACHIAN POWER",
  "Indiana Michigan Power",           "INDIANA MICHIGAN POWER",
  "Kentucky Power",                   "KENTUCKY POWER",
  "Ohio Power",                       "OHIO POWER",
  "Public Service Co. of Oklahoma",   "PUBLIC SERVICE.*OKLAHOMA|PSO",
  "Southwestern Electric Power",      "SOUTHWESTERN ELECTRIC POWER|SWEPCO",
  "AEP Texas",                        "AEP TEXAS",
  "Wheeling Power",                   "WHEELING POWER",
  "Commonwealth Edison",              "COMMONWEALTH EDISON|COMED",
  "Duke Energy Carolinas",            "DUKE ENERGY CAROLINAS",
  "Duke Energy Progress",             "DUKE ENERGY PROGRESS|PROGRESS ENERGY CAROLINA",
  "Duke Energy Florida",              "DUKE ENERGY FLORIDA|PROGRESS ENERGY FLORIDA",
  "Duke Energy Indiana",              "DUKE ENERGY INDIANA",
  "Duke Energy Ohio",                 "DUKE ENERGY OHIO",
  "Duke Energy Kentucky",             "DUKE ENERGY KENTUCKY",
  "Baltimore Gas & Electric (BGE)",   "BALTIMORE GAS|BGE",
  "PECO Energy",                      "^PECO ENERGY",
  "Potomac Electric Power (Pepco)",   "POTOMAC ELECTRIC|PEPCO",
  "Delmarva Power",                   "DELMARVA POWER",
  "Atlantic City Electric",           "ATLANTIC CITY ELECTRIC",
  "Niagara Mohawk",                   "NIAGARA MOHAWK",
  "Massachusetts Electric",           "MASSACHUSETTS ELECTRIC",
  "Nantucket Electric",               "NANTUCKET ELECTRIC",
  "Narragansett Electric",            "NARRAGANSETT ELECTRIC",
  "Pacific Gas & Electric",           "PACIFIC GAS",
  "Northern States Power - MN",       "NORTHERN STATES POWER.*MINNESOTA|NORTHERN STATES POWER CO.*MN",
  "Northern States Power - WI",       "^NORTHERN STATES POWER CO$",
  "Public Service Co. of Colorado",   "PUBLIC SERVICE.*COLORADO",
  "Southwestern Public Service",      "SOUTHWESTERN PUBLIC SERVICE",
  "Arizona Public Service",           "ARIZONA PUBLIC SERVICE",
  "El Paso Electric",                 "EL PASO ELECTRIC",
  "Alabama Power",                    "ALABAMA POWER",
  "Georgia Power",                    "GEORGIA POWER",
  "Mississippi Power",                "MISSISSIPPI POWER",
  "Nevada Power Company",             "^NEVADA POWER",
  "Sierra Pacific Power Company",     "SIERRA PACIFIC POWER",
  "PacifiCorp",                       "^PACIFICORP$",
  "MidAmerican Energy",               "^MIDAMERICAN ENERGY"
)

# For each subsidiary, compute avg annual residential bill per customer by state × year
compute_elec_bill <- function(eia_pattern) {
  eia861 %>%
    filter(
      str_detect(utility_name, regex(eia_pattern, ignore_case = TRUE)),
      !is.na(residential_revenue_usd),
      !is.na(residential_customers),
      residential_customers > 0
    ) %>%
    group_by(state, year) %>%
    summarize(
      avg_annual_bill = sum(residential_revenue_usd, na.rm = TRUE) /
        sum(residential_customers, na.rm = TRUE),
      .groups = "drop"
    )
}

elec_bills <- targets %>%
  distinct(target_holding_co, subsidiary_label) %>%
  left_join(subsidiary_eia_patterns, by = "subsidiary_label") %>%
  filter(!is.na(eia_pattern)) %>%
  mutate(bills = map(eia_pattern, compute_elec_bill)) %>%
  select(target_holding_co, subsidiary_label, bills) %>%
  unnest(bills)

elec_ratios <- elec_bills %>%
  pivot_wider(names_from = year, values_from = avg_annual_bill, names_prefix = "elec_bill_") %>%
  filter(!is.na(elec_bill_2022), !is.na(elec_bill_2024), elec_bill_2022 > 0) %>%
  mutate(elec_ratio = elec_bill_2024 / elec_bill_2022) %>%
  select(target_holding_co, subsidiary_label, state, elec_ratio)

message("  Electricity ratios computed for ", nrow(elec_ratios), " subsidiary × state combos")

# ---- 4. Gas cost ratio per state (EIA 176) -----------------------------------

message("Computing gas cost ratios from EIA 176...")

# State name → abbreviation lookup
state_name_to_abbr <- tibble(
  state_name = state.name,
  state_abbr = state.abb
) %>%
  bind_rows(tibble(state_name = "District of Columbia", state_abbr = "DC"))

eia176 <- read.csv(eia176_path, stringsAsFactors = FALSE) %>%
  filter(year %in% c(2022, 2024)) %>%
  left_join(state_name_to_abbr, by = c("state" = "state_name")) %>%
  filter(!is.na(state_abbr), !is.na(avg_annual_residential_nat_gas_bill),
         avg_annual_residential_nat_gas_bill > 0)

gas_ratios <- eia176 %>%
  select(state_abbr, year, avg_annual_residential_nat_gas_bill) %>%
  pivot_wider(names_from = year, values_from = avg_annual_residential_nat_gas_bill,
              names_prefix = "gas_bill_") %>%
  filter(!is.na(gas_bill_2022), !is.na(gas_bill_2024), gas_bill_2022 > 0) %>%
  mutate(gas_ratio = gas_bill_2024 / gas_bill_2022) %>%
  select(state = state_abbr, gas_ratio)

message("  Gas ratios computed for ", nrow(gas_ratios), " states")

# ---- 5. Load and join DOE LEAD data -----------------------------------------

message("Loading DOE LEAD 2022 data for target states...")

# Map state abbreviation to FIPS prefix (first 2 digits of tract GEOID)
state_fips_map <- tibble(
  state_abbr = target_states,
  fips_prefix = c(
    "01", "05", "04", "06", "08", "11", "10", "12", "13", "19",
    "16", "17", "18", "21", "22", "25", "24", "26", "27", "28",
    "37", "38", "31", "34", "35", "32", "36", "39", "40", "41",
    "42", "44", "45", "46", "47", "48", "49", "51", "53", "55",
    "54", "56"
  )
)

lead_files <- file.path(
  lead_dir,
  paste0(tolower(target_states), "-census_tract-lead-2022.csv")
)

lead_raw <- map2_dfr(lead_files, target_states, function(path, st) {
  if (!file.exists(path)) {
    warning("DOE LEAD file not found: ", path)
    return(NULL)
  }
  read.csv(path, stringsAsFactors = FALSE) %>%
    mutate(
      lead_state_abbr = st,         # distinct name avoids collision with crosswalk's state_abbr
      fip             = as.character(fip)
    )
})

# Pad GEOID to 11 digits (DOE LEAD stores as integer, dropping leading zeros)
lead_raw <- lead_raw %>%
  mutate(fip = str_pad(fip, width = 11, side = "left", pad = "0"))

message("  DOE LEAD loaded: ", nrow(lead_raw), " rows across ", n_distinct(lead_raw$lead_state_abbr), " states")

# ---- 6. Join all components and project to 2024 ------------------------------

message("Joining components and projecting burdens to 2024...")

# Crosswalk: one row per (target_holding_co, subsidiary_label, tract_geoid)
# We need the state for EIA 861 lookup — derive from tract GEOID's FIPS prefix
crosswalk_with_state <- crosswalk %>%
  mutate(
    state_fips = substr(tract_geoid, 1, 2)
  ) %>%
  left_join(state_fips_map, by = c("state_fips" = "fips_prefix"))

# Join DOE LEAD onto crosswalk — many-to-many is expected: each crosswalk row
# (one subsidiary × tract) joins to multiple DOE LEAD subpopulation rows
lead_joined <- crosswalk_with_state %>%
  left_join(lead_raw, by = c("tract_geoid" = "fip"), relationship = "many-to-many") %>%
  filter(!is.na(avg_income))  # drop tracts with no LEAD data

# Join income ratio
lead_joined <- lead_joined %>%
  left_join(income_ratios, by = c("tract_geoid" = "GEOID"))

# Join electricity ratio (subsidiary × state). Many-to-many is expected:
# multiple DOE LEAD subpop rows per (subsidiary, tract) match one elec_ratio row.
lead_joined <- lead_joined %>%
  left_join(
    elec_ratios %>% select(subsidiary_label, state, elec_ratio),
    by = c("subsidiary_label" = "subsidiary_label", "state_abbr" = "state"),
    relationship = "many-to-many"
  )

# Join gas ratio (state-level)
lead_joined <- lead_joined %>%
  left_join(gas_ratios, by = c("state_abbr" = "state"))

# Apply ratios — default missing ratios to 1.0 (no scaling)
lead_projected <- lead_joined %>%
  mutate(
    income_ratio = replace_na(income_ratio, 1.0),
    elec_ratio   = replace_na(elec_ratio,   1.0),
    gas_ratio    = replace_na(gas_ratio,    1.0),

    income_2024        = avg_income           * income_ratio,
    electricity_2024   = avg_electricity_cost * elec_ratio,
    gas_2024           = avg_gas_cost         * gas_ratio,
    other_fuel_2024    = avg_other_fuel_cost,   # held at 2022
    row_burden_2024    = case_when(
      income_2024 > 0 ~ (electricity_2024 + gas_2024 + other_fuel_2024) / income_2024,
      TRUE            ~ NA_real_
    )
  )

# ---- 7. Select output columns and write -------------------------------------

output_cols <- c(
  "target_holding_co", "subsidiary_label", "tract_geoid", "state_abbr",
  "fpl150", "ten_ybl6", "ten_bld", "ten_hfl", "units", "frequency",
  "hincp_valid_units", "elep_valid_units", "gasp_valid_units", "fulp_valid_units",
  "avg_income", "avg_electricity_cost", "avg_gas_cost", "avg_other_fuel_cost",
  "income_ratio", "elec_ratio", "gas_ratio",
  "income_2024", "electricity_2024", "gas_2024", "other_fuel_2024",
  "row_burden_2024"
)

detail_out <- lead_projected %>%
  select(any_of(output_cols))

message("\nProjected burden detail: ", nrow(detail_out), " rows")
message("Rows with valid row_burden_2024: ", sum(!is.na(detail_out$row_burden_2024)))
message("Targets covered: ", n_distinct(detail_out$target_holding_co))

# ---- 8. Ratio sanity check --------------------------------------------------

ratio_summary <- lead_projected %>%
  distinct(subsidiary_label, state_abbr, elec_ratio, gas_ratio, income_ratio) %>%
  summarize(
    elec_ratio_min  = min(elec_ratio,   na.rm = TRUE),
    elec_ratio_max  = max(elec_ratio,   na.rm = TRUE),
    gas_ratio_min   = min(gas_ratio,    na.rm = TRUE),
    gas_ratio_max   = max(gas_ratio,    na.rm = TRUE),
    income_ratio_min = min(income_ratio, na.rm = TRUE),
    income_ratio_max = max(income_ratio, na.rm = TRUE)
  )

message("\nRatio sanity check (expect 0.9–1.5):")
print(ratio_summary)

out_path <- glue("outputs/{format(Sys.Date(), '%d-%m-%Y')}-utility-tract-burden-2024-detail.csv")
write.csv(detail_out, out_path, row.names = FALSE)
message("\nDetail CSV written to: ", out_path)
