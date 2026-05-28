# Load required packages
library(tidyverse)
library(janitor)

# Define target utilities with EPI match names
target_utilities <- tibble(
  target_utility    = c("American Electric Power", "ComEd", "Duke Energy",
                        "Exelon", "National Grid", "PG&E",
                        "Xcel Energy", "Arizona Public Service (APS)",
                        "El Paso Electric", "Southern Company",
                        "NV Energy", "Berkshire Hathaway Energy"),
  epi_utility_name  = c("American Electric Power", NA, "Duke Energy",
                        "Exelon", NA, "PG&E Corporation",
                        "Xcel Energy", NA, NA, "Southern Company",
                        NA, "Berkshire Hathaway Energy"),
  # ComEd matches via Exelon; APS matches via Pinnacle West; NV Energy via BHE parent
  epi_utility_alt   = c(NA, "Exelon", NA,
                        NA, NA, NA,
                        NA, "Pinnacle West", NA, NA,
                        "Berkshire Hathaway Energy", NA),
  match_description = c("direct", "ComEd is operating subsidiary of Exelon", "direct",
                        "direct", NA, "direct",
                        "direct", "APS is operating subsidiary of Pinnacle West",
                        NA, "direct",
                        "NV Energy is operating subsidiary of Berkshire Hathaway Energy", "direct"),
  data_gap_reason   = c(NA, NA, NA,
                        NA, "UK-based parent, no US SEC filings in EPI", NA,
                        NA, NA, "Privately held since 2020 (IIF acquisition)", NA,
                        NA, NA)
)

# Read and clean EPI data
epi_raw <- read.csv("../../Data/epi/EPI_Exec_Comp_Data_2025.csv") %>%
  clean_names()

# For utilities with CEO transitions, keep the highest-compensated row (incumbent)
epi_deduped <- epi_raw %>%
  group_by(utility) %>%
  slice_max(total_compensation, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(utility = str_trim(utility))

# Primary join on epi_utility_name
primary_match <- target_utilities %>%
  left_join(
    epi_deduped %>% select(utility, name, total_compensation),
    by = c("epi_utility_name" = "utility")
  )

# Alternate join for rows with no primary match (ComEd, APS)
output <- primary_match %>%
  left_join(
    epi_deduped %>%
      select(utility, name, total_compensation) %>%
      rename(alt_utility = utility, alt_name = name, alt_comp = total_compensation),
    by = c("epi_utility_alt" = "alt_utility")
  ) %>%
  mutate(
    epi_match         = coalesce(epi_utility_name, epi_utility_alt),
    ceo_name          = coalesce(name, alt_name),
    ceo_pay_usd       = coalesce(total_compensation, alt_comp),
    match_description = case_when(
      is.na(epi_match) ~ data_gap_reason,
      TRUE             ~ match_description
    )
  ) %>%
  select(
    target_utility,
    epi_match,
    match_description,
    ceo_name,
    ceo_pay_usd
  )

write.csv(
  output,
  paste0("outputs/", format(Sys.Date(), "%d-%m-%Y"), "-epi-exec-comp.csv"),
  row.names = FALSE
)

message("Done. ", sum(!is.na(output$ceo_name)), "/12 utilities matched.")
print(output)
