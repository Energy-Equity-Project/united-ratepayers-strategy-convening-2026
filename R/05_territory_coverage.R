# Scoping check: which HIFLD/ORNL service-territory polygons match each of
# the 10 target IOUs (and their known operating subsidiaries) for the
# United Ratepayers Strategy Convening 2026 project.
#
# Run from repo root:
#   Rscript R/05_territory_coverage.R
#
# Writes: outputs/<dd-mm-yyyy>-territory-coverage-gap-report.md
# Prints: console summary of matches/misses

library(tidyverse)
library(sf)
library(glue)

source("R/lib/target_subsidiaries.R")

# ---- 1. Load shapefile ------------------------------------------------------

shp_path <- file.path(
  "..", "..",
  "Data", "gis", "hflid_ornl",
  "electric-retail-service-territories",
  "electric-retail-service-territories-shapefile",
  "Electric_Retail_Service_Territories.shp"
)

territories <- st_read(shp_path, quiet = TRUE) %>%
  st_drop_geometry() %>%
  mutate(
    feature_id = row_number(),
    # HIFLD uses -999999 as a sentinel for missing numeric data
    CUSTOMERS = na_if(CUSTOMERS, -999999),
    RETAIL_MWH = na_if(RETAIL_MWH, -999999)
  )

# targets tibble is sourced from R/lib/target_subsidiaries.R above.
# The shared table includes Commonwealth Edison under both "ComEd" and "Exelon"
# (overlap policy: ComEd tracts roll up into both targets). Exelon therefore
# shows 6 expected subsidiaries in this gap report.

# ---- 3. Matching logic ------------------------------------------------------

# Per-subsidiary matching: use NAME regex to pinpoint the specific operating
# utility. (Earlier we tried OR'ing with HOLDING_CO, but that swept every
# feature under the parent into every subsidiary lookup.)
#
# The holding_co_regex column is used separately below to audit each parent
# company for features the curated subsidiary list didn't claim.

match_by_name <- function(name_regex) {
  territories %>%
    filter(str_detect(NAME, regex(name_regex, ignore_case = TRUE)))
}

matches <- targets %>%
  mutate(matched = map(name_regex, match_by_name)) %>%
  mutate(n_matched = map_int(matched, nrow))

# Long-form: one row per matched feature
matches_long <- matches %>%
  select(target_holding_co, subsidiary_label, expected_states, matched) %>%
  unnest(matched) %>%
  select(target_holding_co, subsidiary_label, expected_states,
         NAME, HOLDING_CO, STATE, TYPE, CUSTOMERS, RETAIL_MWH, feature_id)

# Flag type mismatches: matches that are clearly the wrong ownership type
matches_long <- matches_long %>%
  mutate(
    type_warning = case_when(
      TYPE %in% c("COOPERATIVE", "MUNICIPAL", "FEDERAL", "STATE",
                  "POLITICAL SUBDIVISION", "COMMUNITY CHOICE AGGREGATOR",
                  "MUNICIPAL MKTG AUTHORITY") ~ TRUE,
      TRUE ~ FALSE
    ),
    state_warning = case_when(
      is.na(STATE) ~ FALSE,
      str_detect(expected_states, fixed(STATE)) ~ FALSE,
      TRUE ~ TRUE
    )
  )

# Per-subsidiary summary
subsidiary_summary <- matches %>%
  mutate(
    states_matched = map_chr(matched, ~ {
      if (nrow(.x) == 0) return("")
      .x %>% pull(STATE) %>% unique() %>% sort() %>% paste(collapse = ",")
    }),
    total_customers = map_dbl(matched, ~ sum(.x$CUSTOMERS, na.rm = TRUE)),
    total_retail_mwh = map_dbl(matched, ~ sum(.x$RETAIL_MWH, na.rm = TRUE))
  ) %>%
  select(target_holding_co, subsidiary_label, expected_states,
         n_matched, states_matched, total_customers, total_retail_mwh)

# Per-holding-company tally (deduplicate feature_id across subsidiaries within
# the same parent — some regex patterns can legitimately overlap, e.g.
# Pepco and Delmarva both under Exelon/Pepco Holdings)
holding_features <- matches_long %>%
  distinct(target_holding_co, feature_id, CUSTOMERS)

holding_tally <- subsidiary_summary %>%
  group_by(target_holding_co) %>%
  summarize(
    subsidiaries_expected = n(),
    subsidiaries_matched = sum(n_matched > 0),
    subsidiaries_missing = sum(n_matched == 0)
  ) %>%
  ungroup() %>%
  left_join(
    holding_features %>%
      group_by(target_holding_co) %>%
      summarize(
        unique_territories = n(),
        total_customers = sum(CUSTOMERS, na.rm = TRUE)
      ) %>%
      ungroup(),
    by = "target_holding_co"
  ) %>%
  arrange(desc(subsidiaries_missing), target_holding_co)

# ---- 3b. Holding-company audit ----------------------------------------------
#
# For each parent, find all features whose HOLDING_CO matches the parent's
# holding_co_regex but were NOT claimed by any curated subsidiary lookup.
# These are candidates we may have missed.

# Collapse multiple holding_co_regex values per parent into a single pattern
holding_patterns <- targets %>%
  distinct(target_holding_co, holding_co_regex) %>%
  group_by(target_holding_co) %>%
  summarize(combined_regex = paste(unique(holding_co_regex), collapse = "|"), .groups = "drop")

# All feature_ids claimed by ANY target — used to exclude cross-target
# overlaps (e.g., COMMONWEALTH EDISON CO has HOLDING_CO = EXELON CORP and
# would otherwise surface under Exelon's audit, but it's claimed under the
# separate ComEd target)
all_claimed_ids <- unique(matches_long$feature_id)

holding_audit <- holding_patterns %>%
  mutate(
    hc_features = map(combined_regex, ~ {
      territories %>%
        filter(str_detect(replace_na(HOLDING_CO, ""), regex(.x, ignore_case = TRUE)))
    }),
    unclaimed = map(hc_features, ~ .x %>% filter(!feature_id %in% all_claimed_ids)),
    n_hc_total = map_int(hc_features, nrow),
    n_unclaimed = map_int(unclaimed, nrow)
  )

# ---- 4. Markdown gap report -------------------------------------------------

report_path <- file.path(
  "outputs",
  glue("{format(Sys.Date(), '%d-%m-%Y')}-territory-coverage-gap-report.md")
)

# Build "Notable findings" — targets with any miss
notable <- holding_tally %>%
  filter(subsidiaries_missing > 0) %>%
  mutate(line = glue("- **{target_holding_co}**: {subsidiaries_missing} of {subsidiaries_expected} expected subsidiaries not found")) %>%
  pull(line)

# Also flag any type warnings
type_warns <- matches_long %>%
  filter(type_warning) %>%
  count(target_holding_co, subsidiary_label, TYPE, name = "n") %>%
  mutate(line = glue("- **{target_holding_co} / {subsidiary_label}**: {n} match(es) flagged as {TYPE} (likely false positive)")) %>%
  pull(line)

report_lines <- c(
  glue("# HIFLD Service Territory Coverage — Gap Report"),
  "",
  glue("**Generated:** {format(Sys.Date(), '%Y-%m-%d')}"),
  glue("**Shapefile:** `Data/gis/hflid_ornl/.../Electric_Retail_Service_Territories.shp` ({nrow(territories)} features)"),
  glue("**Targets:** {n_distinct(targets$target_holding_co)} holding companies / {nrow(targets)} expected operating subsidiaries"),
  "",
  "## Notable findings",
  "",
  if (length(notable) == 0) "_All expected subsidiaries matched at least one territory._" else paste(notable, collapse = "\n"),
  "",
  if (length(type_warns) > 0) c("### Type-mismatch warnings (likely false positives)", "", paste(type_warns, collapse = "\n"), "") else NULL,
  "## Coverage by holding company",
  ""
)

# Per-holding-company sections
for (hc in unique(targets$target_holding_co)) {
  hc_subs <- subsidiary_summary %>% filter(target_holding_co == hc)
  hc_tally <- holding_tally %>% filter(target_holding_co == hc)

  report_lines <- c(
    report_lines,
    glue("### {hc}"),
    "",
    glue("- Expected subsidiaries: {hc_tally$subsidiaries_expected}"),
    glue("- Matched: {hc_tally$subsidiaries_matched}; Missing: {hc_tally$subsidiaries_missing}"),
    glue("- Unique territories matched: {hc_tally$unique_territories}"),
    glue("- Total customers across matches: {formatC(hc_tally$total_customers, format = 'd', big.mark = ',')}"),
    "",
    "| Subsidiary | # matched | States matched | Expected states | Customers |",
    "|---|---|---|---|---|"
  )
  for (i in seq_len(nrow(hc_subs))) {
    row <- hc_subs[i, ]
    status_marker <- if (row$n_matched == 0) " :warning:" else ""
    report_lines <- c(
      report_lines,
      glue("| {row$subsidiary_label}{status_marker} | {row$n_matched} | {row$states_matched} | {row$expected_states} | {formatC(row$total_customers, format = 'd', big.mark = ',')} |")
    )
  }
  report_lines <- c(report_lines, "")

  # Per-subsidiary match detail (only show first few features per subsidiary)
  hc_long <- matches_long %>% filter(target_holding_co == hc)
  if (nrow(hc_long) > 0) {
    report_lines <- c(
      report_lines,
      glue("#### {hc} — matched features (top per subsidiary)"),
      "",
      "| Subsidiary | NAME | HOLDING_CO | STATE | TYPE | Customers | Warnings |",
      "|---|---|---|---|---|---|---|"
    )
    show <- hc_long %>%
      group_by(subsidiary_label) %>%
      slice_head(n = 8) %>%
      ungroup()
    for (i in seq_len(nrow(show))) {
      row <- show[i, ]
      warns <- c(
        if (row$type_warning) glue("type:{row$TYPE}") else NULL,
        if (row$state_warning) glue("state:{row$STATE} not in {row$expected_states}") else NULL
      ) %>% paste(collapse = "; ")
      report_lines <- c(
        report_lines,
        glue("| {row$subsidiary_label} | {row$NAME} | {row$HOLDING_CO} | {row$STATE} | {row$TYPE} | {formatC(row$CUSTOMERS, format = 'd', big.mark = ',')} | {warns} |")
      )
    }
    report_lines <- c(report_lines, "")
  }
}

# Holding-co audit section: features under each parent's HOLDING_CO not
# claimed by any curated subsidiary
report_lines <- c(
  report_lines,
  "## Holding-company audit (unclaimed features)",
  "",
  "Features whose `HOLDING_CO` matches each parent's pattern but were not picked up by any curated subsidiary lookup. These are candidates that may need to be added to the subsidiary list.",
  ""
)
for (i in seq_len(nrow(holding_audit))) {
  hc <- holding_audit$target_holding_co[i]
  n_total <- holding_audit$n_hc_total[i]
  n_unc <- holding_audit$n_unclaimed[i]
  report_lines <- c(
    report_lines,
    glue("### {hc}"),
    glue("- Features under HOLDING_CO pattern: {n_total}"),
    glue("- Unclaimed (not matched by any subsidiary regex): {n_unc}"),
    ""
  )
  if (n_unc > 0) {
    unc <- holding_audit$unclaimed[[i]] %>%
      select(NAME, HOLDING_CO, STATE, TYPE, CUSTOMERS) %>%
      arrange(desc(CUSTOMERS))
    report_lines <- c(
      report_lines,
      "| NAME | HOLDING_CO | STATE | TYPE | Customers |",
      "|---|---|---|---|---|"
    )
    for (j in seq_len(nrow(unc))) {
      r <- unc[j, ]
      report_lines <- c(
        report_lines,
        glue("| {r$NAME} | {r$HOLDING_CO} | {r$STATE} | {r$TYPE} | {formatC(r$CUSTOMERS, format = 'd', big.mark = ',')} |")
      )
    }
    report_lines <- c(report_lines, "")
  }
}

# Add Gulf Power divestiture note
report_lines <- c(
  report_lines,
  "## Caveats",
  "",
  "- **Gulf Power**: Southern Company divested Gulf Power to NextEra in 2019 — confirmed absent from shapefile under SOUTHERN COMPANY holding co.",
  "- **El Paso Electric**: Privately held since 2020 (acquired by IIF). Territory present in shapefile (HOLDING_CO still 'EL PASO ELECTRIC POWER COMPANY').",
  "- **HIFLD `TYPE` field**: ~57% of features lack a TYPE classification (`NOT AVAILABLE`). Type-mismatch warnings only flag definitively non-IOU types (COOP, MUNI, etc.).",
  "- **HIFLD `STATE` field is unreliable for territory location**: For some utilities (notably all AEP subsidiaries, both Northern States Power entries) the `STATE` field reflects the holding company's HQ state, not the polygon's service-territory state. Many `state:X not in Y` warnings in the tables above are caused by this, not by mismatched data. Use the polygon geometry, not the STATE attribute, for territory-state assignment in downstream analysis.",
  "- **Narragansett Electric (RI)**: National Grid sold Narragansett Electric to PPL in 2022. The shapefile (vintage August 2023) still lists HOLDING_CO = 'NATIONAL GRID GROUP PLC'. Included in National Grid target list as a known historical subsidiary — review whether to attribute its territory to NG or PPL depending on the analysis year."
)

writeLines(report_lines, report_path)

# ---- 5. Console summary -----------------------------------------------------

cat("\n", strrep("=", 70), "\n", sep = "")
cat("HIFLD SERVICE TERRITORY COVERAGE — CONSOLE SUMMARY\n")
cat(strrep("=", 70), "\n\n", sep = "")

cat("Per-holding-company tally:\n\n")
print(holding_tally, n = Inf)

cat("\n\nSubsidiaries with ZERO matches (gaps):\n\n")
gaps <- subsidiary_summary %>% filter(n_matched == 0)
if (nrow(gaps) == 0) {
  cat("  (none — every expected subsidiary matched at least one territory)\n")
} else {
  print(gaps %>% select(target_holding_co, subsidiary_label, expected_states), n = Inf)
}

cat("\n\nUnclaimed features per holding co (audit):\n\n")
audit_summary <- holding_audit %>%
  select(target_holding_co, n_hc_total, n_unclaimed)
print(audit_summary, n = Inf)

cat("\n\nSpot-check anchors:\n\n")
spot <- matches_long %>%
  filter(
    (subsidiary_label == "Pacific Gas & Electric") |
      (subsidiary_label == "Georgia Power") |
      (subsidiary_label == "Ohio Power") |
      (subsidiary_label == "El Paso Electric")
  ) %>%
  select(subsidiary_label, NAME, HOLDING_CO, STATE, TYPE, CUSTOMERS)
print(spot, n = Inf)

cat("\nGulf Power presence check:\n")
gulf <- territories %>%
  filter(str_detect(NAME, regex("GULF POWER", ignore_case = TRUE))) %>%
  select(NAME, HOLDING_CO, STATE, TYPE, CUSTOMERS)
print(gulf, n = Inf)

cat("\nReport written to:", report_path, "\n")
