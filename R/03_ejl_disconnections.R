# EJL Disconnection Dashboard — per-utility shutoffs for 10 target IOUs
#
# Source: Energy Justice Lab Utility Disconnection Dashboard (utilitydisconnections.org)
# Cleaned data: ../../Cleaned_Data/ejl_disconnection_dashboard/16-03-2026-ejl-disconnection-dashboard.csv
#
# EJL disconnection data covers shutoffs for non-payment specifically.
#
# Year selection: for each matched (utility_name, state, service_type), this script uses the
# most recent calendar year with all 12 months reported. Combos with no full year are excluded
# from totals and printed to console as gaps.

library(tidyverse)
library(janitor)

# ============================================================
# 1. COMBINED-ROW EXCLUSION
# ============================================================
# These EJL utility_name strings are aggregated "combined customer" rows that overlap
# with already-matched separate Electric and Gas rows for the same utility.
# Excluding them from the full dataset prevents double-counting.
combined_customer_rows <- c(
  "PECO - Electric and Gas Customers",               # Exelon/PECO: separate Electric + Gas rows also in EJL
  "Xcel Energy - Electric and Gas Combined Customers" # Xcel CO: separate Electric + Gas rows also in EJL
)

# ============================================================
# 2. TARGET UTILITIES WITH EJL MATCH STRATEGY
# ============================================================
target_utilities <- tibble(
  target_utility = c(
    "American Electric Power", "ComEd", "Duke Energy",
    "Exelon", "National Grid", "PG&E",
    "Xcel Energy", "Arizona Public Service (APS)",
    "El Paso Electric", "Southern Company"
  ),
  match_type = c(
    "substring", "exact", "substring",
    "exact", "exact", "exact",
    "substring", "exact",
    "substring", "exact"
  ),
  match_values = list(
    # AEP: SWEPCO (Southwestern Electric Power) and PSO (Public Service Oklahoma) absent from EJL
    c("AEP ", "Appalachian Power", "Indiana Michigan", "Kentucky Power", "Ohio Power"),
    "Commonwealth Edison",
    "Duke Energy",
    # Exelon: Pepco and Atlantic City Electric absent from EJL as operating utilities;
    # "PECO - Electric and Gas Customers" excluded globally above to prevent double-counting
    c("Baltimore Gas and Electric Company", "Delmarva Power", "PECO - Electric", "PECO - Gas"),
    c("Massachusetts Electric Company", "Nantucket Electric Company", "Niagara Mohawk Power Corp",
      "KeySpan Energy Delivery Long Island (KEDLI)", "KeySpan Energy Delivery New York (KEDNY)",
      "The Brooklyn Union Gas Company d/b/a National Grid NY"),
    "Pacific Gas & Electric Co",
    # Xcel: "Xcel Energy - Electric and Gas Combined Customers" excluded globally above;
    # Southwestern Public Service Company (NM) is an Xcel sub (SPS)
    c("Xcel Energy", "Northern States Power", "Southwestern Public Service"),
    "Arizona Public Service Company",
    "El Paso Electric",
    # Southern Company: Alabama Power and Mississippi Power absent from EJL — gaps expected
    c("Georgia Power", "Alabama Power", "Mississippi Power")
  ),
  match_description = c(
    "Substring match on AEP Texas, Appalachian Power (VA), Indiana Michigan Power (IN/MI), Kentucky Power Company, Ohio Power Company; SWEPCO and PSO absent from EJL",
    "Exact match: Commonwealth Edison (IL)",
    "Substring 'Duke Energy' catches all DE operating subsidiaries across NC, SC, FL, IN, KY, OH",
    "Exact match: Baltimore Gas and Electric, Delmarva Power, PECO - Electric, PECO - Gas; Pepco and Atlantic City Electric absent from EJL; PECO combined-customer row excluded globally",
    "Exact match: Massachusetts Electric, Nantucket Electric, Niagara Mohawk, KeySpan KEDLI, KeySpan KEDNY, Brooklyn Union Gas d/b/a National Grid NY",
    "Exact match: Pacific Gas & Electric Co (CA)",
    "Substring match on Xcel Energy (MN/CO), Northern States Power (WI/MI/ND/SD), Southwestern Public Service (NM); Xcel CO combined-customer row excluded globally",
    "Exact match: Arizona Public Service Company (AZ)",
    "Substring 'El Paso Electric' catches El Paso Electric Company (NM)",
    "Exact match: Georgia Power (GA); Alabama Power and Mississippi Power absent from EJL — documented as gaps"
  )
)

# ============================================================
# 3. LOAD AND CLEAN EJL DATA
# ============================================================
ejl_raw <- read.csv(
  "../../Cleaned_Data/ejl_disconnection_dashboard/16-03-2026-ejl-disconnection-dashboard.csv",
  stringsAsFactors = FALSE
) %>%
  mutate(
    year  = as.integer(year),
    month = as.integer(month)
  )

# Remove combined-customer rows before any matching
n_excluded <- sum(ejl_raw$utility_name %in% combined_customer_rows)
message("Excluding ", n_excluded, " combined-customer row(s) to prevent double-counting: ",
        paste(combined_customer_rows[combined_customer_rows %in% ejl_raw$utility_name], collapse = "; "))
ejl <- ejl_raw %>%
  filter(!utility_name %in% combined_customer_rows)

# ============================================================
# 4. HELPERS
# ============================================================

# Filter EJL rows for one target based on its match strategy
filter_ejl_target <- function(df, match_type, match_values) {
  if (match_type == "exact") {
    df[df$utility_name %in% match_values, ]
  } else {
    pattern <- paste(match_values, collapse = "|")
    df[str_detect(df$utility_name, pattern), ]
  }
}

# For a matched subset, return the most recent full calendar year per
# (utility_name, state, service_type). Rows with no year having 12 months are dropped.
select_full_years <- function(df) {
  df %>%
    group_by(utility_name, state, service_type, year) %>%
    summarise(
      n_months             = n(),
      total_disconnections = sum(total_disconnections, na.rm = TRUE),
      total_reconnections  = sum(total_reconnections, na.rm = TRUE),
      total_connections    = mean(total_connections, na.rm = TRUE),
      disconnection_rate_avg = mean(disconnection_rate, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(n_months == 12) %>%
    group_by(utility_name, state, service_type) %>%
    filter(year == max(year)) %>%
    ungroup()
}

# ============================================================
# 5. BUILD DETAIL TABLE
# ============================================================
detail_list <- list()
gap_list    <- list()

for (i in seq_len(nrow(target_utilities))) {
  target       <- target_utilities$target_utility[i]
  match_type   <- target_utilities$match_type[i]
  match_values <- target_utilities$match_values[[i]]

  matched <- filter_ejl_target(ejl, match_type, match_values)

  message("\n", target, " — ", n_distinct(matched$utility_name), " utility_name(s) matched:")
  if (nrow(matched) > 0) {
    walk(sort(unique(matched$utility_name)), ~ message("  \u2022 ", .x))
  } else {
    message("  [NO MATCH]")
    gap_list[[target]] <- tibble(
      target_utility = target,
      utility_name   = NA_character_,
      state          = NA_character_,
      service_type   = NA_character_,
      reason         = "no_match_in_ejl"
    )
    next
  }

  full_year_data <- select_full_years(matched)

  # Identify (utility_name, state, service_type) combos with no full year
  all_combos <- matched %>% distinct(utility_name, state, service_type)
  full_combos <- full_year_data %>% distinct(utility_name, state, service_type)
  no_full_year <- anti_join(all_combos, full_combos,
                             by = c("utility_name", "state", "service_type"))

  if (nrow(no_full_year) > 0) {
    message("  \u26a0 No full year (12 months) found for:")
    walk(seq_len(nrow(no_full_year)), function(j) {
      message("    - ", no_full_year$utility_name[j],
              " (", no_full_year$state[j], ", ", no_full_year$service_type[j], ")")
    })
    gap_list[[target]] <- no_full_year %>%
      mutate(target_utility = target, reason = "no_full_year")
  }

  detail_list[[target]] <- full_year_data %>%
    mutate(target_utility = target)
}

# Combine all detail rows
detail <- bind_rows(detail_list) %>%
  rename(
    year_used            = year,
    n_months_in_year_used = n_months
  ) %>%
  select(
    target_utility, utility_name, state, service_type,
    year_used, n_months_in_year_used,
    total_disconnections, total_reconnections,
    total_connections, disconnection_rate_avg
  )

# ============================================================
# 6. BUILD SUMMARY TABLE (one row per target)
# ============================================================
summary_tbl <- pmap_dfr(
  target_utilities,
  function(target_utility, match_type, match_values, match_description) {
    rows <- detail %>% filter(target_utility == !!target_utility)

    n_no_full_year <- if (!is.null(gap_list[[target_utility]])) {
      gap_list[[target_utility]] %>% filter(reason == "no_full_year") %>% nrow()
    } else {
      0L
    }

    if (nrow(rows) == 0) {
      tibble(
        target_utility             = target_utility,
        n_subsidiaries_matched     = 0L,
        subsidiaries_matched       = NA_character_,
        states_covered             = NA_character_,
        year_range_used            = NA_character_,
        electric_disconnections    = NA_real_,
        gas_disconnections         = NA_real_,
        combined_disconnections    = NA_real_,
        electric_reconnections     = NA_real_,
        gas_reconnections          = NA_real_,
        n_subsidiaries_no_full_year = n_no_full_year,
        match_description          = match_description
      )
    } else {
      rows %>%
        summarise(
          n_subsidiaries_matched  = n_distinct(paste(utility_name, state, service_type)),
          subsidiaries_matched    = paste(sort(unique(utility_name)), collapse = "; "),
          states_covered          = paste(sort(unique(state)), collapse = "; "),
          year_range_used         = paste(min(year_used), max(year_used), sep = "-"),
          electric_disconnections = sum(total_disconnections[service_type == "Electric"], na.rm = TRUE),
          gas_disconnections      = sum(total_disconnections[service_type == "Gas"], na.rm = TRUE),
          combined_disconnections = sum(total_disconnections[service_type == "Electric and Gas"], na.rm = TRUE),
          electric_reconnections  = sum(total_reconnections[service_type == "Electric"], na.rm = TRUE),
          gas_reconnections       = sum(total_reconnections[service_type == "Gas"], na.rm = TRUE)
        ) %>%
        mutate(
          target_utility              = target_utility,
          n_subsidiaries_no_full_year = n_no_full_year,
          match_description           = match_description
        ) %>%
        select(
          target_utility, n_subsidiaries_matched, subsidiaries_matched,
          states_covered, year_range_used,
          electric_disconnections, gas_disconnections, combined_disconnections,
          electric_reconnections, gas_reconnections,
          n_subsidiaries_no_full_year, match_description
        )
    }
  }
)

# ============================================================
# 7. WRITE OUTPUTS
# ============================================================
out_date <- format(Sys.Date(), "%d-%m-%Y")

write.csv(
  summary_tbl,
  paste0("outputs/", out_date, "-united-ratepayers-shutoffs.csv"),
  row.names = FALSE
)

write.csv(
  detail,
  paste0("outputs/", out_date, "-united-ratepayers-shutoffs-detail.csv"),
  row.names = FALSE
)

message("\n============================")
message("Done.")
message("Summary CSV: ", nrow(summary_tbl), " rows → outputs/", out_date, "-united-ratepayers-shutoffs.csv")
message("Detail CSV:  ", nrow(detail), " rows → outputs/", out_date, "-united-ratepayers-shutoffs-detail.csv")
message("============================\n")

print(
  summary_tbl %>%
    select(target_utility, n_subsidiaries_matched, electric_disconnections,
           gas_disconnections, combined_disconnections, n_subsidiaries_no_full_year)
)
