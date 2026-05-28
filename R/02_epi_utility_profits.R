# Load required packages
library(tidyverse)
library(janitor)
library(readxl)

# Define target utilities with EPI match strategy
target_utilities <- tibble(
  target_utility = c(
    "American Electric Power", "ComEd", "Duke Energy",
    "Exelon", "National Grid", "PG&E",
    "Xcel Energy", "Arizona Public Service (APS)",
    "El Paso Electric", "Southern Company",
    "NV Energy", "Berkshire Hathaway Energy"
  ),
  match_column = c(
    "parent", "utility", "utility",
    "parent", "parent", "parent",
    "utility", "utility",
    "utility", "parent",
    "utility", "parent"
  ),
  match_type = c(
    "exact", "exact", "substring",
    "exact", "exact", "exact",
    "substring", "exact",
    "exact", "exact",
    "substring", "exact"
  ),
  match_values = list(
    "American Electric Power",
    "ComEd",
    "Duke Energy",
    "Exelon",
    "National Grid",
    "PG&E",
    c("Xcel", "Northern States Power", "Public Service Co. of Colorado", "Southwestern Public Service"),
    "Arizona Public Service Co. (APS)",
    "El Paso Electric",
    "Southern Company",
    c("Nevada Power", "Sierra Pacific"),
    "Berkshire Hathaway Energy"
  ),
  match_description = c(
    "Summed via Parent Company = 'American Electric Power'",
    "Operating-utility row; Utility = 'ComEd' (distinct from Exelon parent total)",
    "Special case: Parent Company inconsistent in EPI source; matched via Utility substring 'Duke Energy'",
    "Summed via Parent Company = 'Exelon' (overlaps with ComEd target by design)",
    "Summed via Parent Company = 'National Grid'",
    "Summed via Parent Company = 'PG&E'",
    "'Xcel' absent from Parent Company column; aggregated via Utility-name substring matching",
    "Operating-utility row; Utility = 'Arizona Public Service Co. (APS)' (distinct from Pinnacle West parent)",
    "Single row; Utility = 'El Paso Electric'",
    "Summed via Parent Company = 'Southern Company'",
    "Operating-utility rows; Utility substring matches Nevada Power + Sierra Pacific (NV Energy d/b/a)",
    "Summed via Parent Company = 'Berkshire Hathaway Energy' (overlaps with NV Energy target by design; rolls up Nevada Power + Sierra Pacific + PacifiCorp + MidAmerican)"
  )
)

# Read and clean EPI utility profits data
epi_raw <- read_excel(
  "../../Data/epi/2021 - 2025 Utility Profits (Make a copy to edit) _ Last Updated 5_8_26.xlsx",
  sheet = "Data"
) %>%
  clean_names() %>%
  mutate(across(starts_with("x20"), as.numeric))

# Filter EPI rows for one target based on its match strategy
filter_target <- function(df, match_column, match_type, match_values) {
  col_vals <- if (match_column == "parent") df$parent_company else df$utility
  if (match_type == "exact") {
    df[col_vals %in% match_values, ]
  } else {
    pattern <- paste(match_values, collapse = "|")
    df[str_detect(col_vals, pattern), ]
  }
}

# Build one summary row per target utility
results <- pmap_dfr(
  target_utilities,
  function(target_utility, match_column, match_type, match_values, match_description) {

    matched <- filter_target(epi_raw, match_column, match_type, match_values)

    message("\n", target_utility, " — ", nrow(matched), " row(s) matched:")
    if (nrow(matched) > 0) {
      walk(matched$utility, ~ message("  \u2022 ", .x))
    } else {
      message("  [NO MATCH]")
    }

    matched %>%
      summarise(
        subsidiaries_matched   = paste(utility, collapse = "; "),
        n_subsidiaries         = n(),
        profit_2021_millions   = sum(x2021_profit_millions, na.rm = TRUE),
        profit_2024_millions   = sum(x2024_profit_millions, na.rm = TRUE),
        profit_2025_millions   = sum(x2025_profit_millions, na.rm = TRUE)
      ) %>%
      mutate(
        target_utility         = target_utility,
        epi_match_column       = match_column,
        epi_match_values       = paste(match_values, collapse = "; "),
        profit_ratio_2024_2025 = profit_2025_millions / profit_2024_millions,
        profit_ratio_2021_2025 = profit_2025_millions / profit_2021_millions,
        match_description      = match_description
      ) %>%
      select(
        target_utility, epi_match_column, epi_match_values,
        subsidiaries_matched, n_subsidiaries,
        profit_2021_millions, profit_2024_millions, profit_2025_millions,
        profit_ratio_2024_2025, profit_ratio_2021_2025,
        match_description
      )
  }
)

write.csv(
  results,
  paste0("outputs/", format(Sys.Date(), "%d-%m-%Y"), "-epi-utility-profits.csv"),
  row.names = FALSE
)

message("\nDone. ", sum(results$n_subsidiaries > 0), "/12 utilities matched.")
print(results %>% select(target_utility, n_subsidiaries, profit_2025_millions,
                          profit_ratio_2024_2025, profit_ratio_2021_2025))
