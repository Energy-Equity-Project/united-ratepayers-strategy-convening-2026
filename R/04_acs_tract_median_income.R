library(tidyverse)

source("../../Internal/data-pipelines/eep-pipeline-core/collectors/acs_collector.R")

# States derived from HIFLD coverage audit: outputs/24-05-2026-territory-coverage-gap-report.md
target_states <- c(
  "AL", "AR", "AZ", "CA", "CO", "DC", "DE", "FL", "GA", "IL",
  "IN", "KY", "LA", "MA", "MD", "MI", "MN", "MS", "NC", "ND",
  "NJ", "NM", "NY", "OH", "OK", "PA", "RI", "SC", "SD", "TN",
  "TX", "VA", "WI", "WV"
)

years     <- c(2022, 2024)
base_path <- "../../Data/us_census/acs"

run_grid <- expand_grid(year = years, state = target_states)

walk2(run_grid$year, run_grid$state, function(year, state) {
  acs_collect(
    variables = "B19013_001",
    geography = "tract",
    year      = year,
    state     = state,
    survey    = "acs5",
    base_path = base_path
  )
})

registry <- acs_get_registry(base_path) %>%
  filter(
    table_code == "B19013",
    year       %in% years,
    state      %in% tolower(target_states)
  )

message("Done. ", nrow(registry), " files written; ", sum(registry$n_rows), " total tracts collected.")
