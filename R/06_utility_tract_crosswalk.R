# Build a utility → census-tract crosswalk for the 10 target holding companies.
#
# Method: for each operating subsidiary's matched HIFLD service-territory
# polygon(s), find all 2022 census tract centroids that fall within the union
# of those polygons (centroid-in-polygon). A tract whose centroid falls in
# multiple targets is counted under each independently (e.g. ComEd tracts also
# appear under Exelon).
#
# Inputs:
#   HIFLD shapefile  : ../../Data/gis/hflid_ornl/.../Electric_Retail_Service_Territories.shp
#   Census tracts    : ../../Data/gis/census/cb_2022_us_tract_500k/cb_2022_us_tract_500k.shp
#   Subsidiary table : R/lib/target_subsidiaries.R
#
# Output:
#   outputs/<dd-mm-yyyy>-utility-tract-crosswalk.csv
#   Columns: target_holding_co, subsidiary_label, expected_states, tract_geoid, hifld_feature_id

library(tidyverse)
library(sf)
library(glue)

source("R/lib/target_subsidiaries.R")

# ---- 1. Load HIFLD shapefile (keep geometry) ---------------------------------

shp_path <- file.path(
  "..", "..",
  "Data", "gis", "hflid_ornl",
  "electric-retail-service-territories",
  "electric-retail-service-territories-shapefile",
  "Electric_Retail_Service_Territories.shp"
)

message("Loading HIFLD shapefile...")
hifld <- st_read(shp_path, quiet = TRUE) %>%
  mutate(
    hifld_feature_id = row_number(),
    CUSTOMERS  = na_if(CUSTOMERS,  -999999),
    RETAIL_MWH = na_if(RETAIL_MWH, -999999)
  )

# ---- 2. Load 2022 cartographic census tracts (nationwide) --------------------

tract_path <- file.path(
  "..", "..",
  "Data", "gis", "census",
  "cb_2022_us_tract_500k",
  "cb_2022_us_tract_500k.shp"
)

# Target state FIPS codes (42 states from ACS collection — 2026 expansion adds
# NV, OR, WA, UT, WY, ID, IA, NE for NV Energy + PacifiCorp + MidAmerican)
target_state_fips <- c(
  "01", # AL
  "05", # AR
  "04", # AZ
  "06", # CA
  "08", # CO
  "11", # DC
  "10", # DE
  "12", # FL
  "13", # GA
  "19", # IA
  "16", # ID
  "17", # IL
  "18", # IN
  "21", # KY
  "22", # LA
  "25", # MA
  "24", # MD
  "26", # MI
  "27", # MN
  "28", # MS
  "37", # NC
  "38", # ND
  "31", # NE
  "34", # NJ
  "35", # NM
  "32", # NV
  "36", # NY
  "39", # OH
  "40", # OK
  "41", # OR
  "42", # PA
  "44", # RI
  "45", # SC
  "46", # SD
  "47", # TN
  "48", # TX
  "49", # UT
  "51", # VA
  "53", # WA
  "55", # WI
  "54", # WV
  "56"  # WY
)

message("Loading census tract shapefile (filtering to 34 target states)...")
tracts <- st_read(tract_path, quiet = TRUE) %>%
  filter(STATEFP %in% target_state_fips) %>%
  select(GEOID, STATEFP, COUNTYFP, TRACTCE)

# Align CRS
if (st_crs(tracts) != st_crs(hifld)) {
  tracts <- st_transform(tracts, st_crs(hifld))
}

# Pre-compute tract centroids (suppress warnings about geographic CRS)
message("Computing tract centroids...")
tract_centroids <- suppressWarnings(st_centroid(tracts))

# ---- 3. Helper: match HIFLD features by subsidiary name regex ---------------

match_hifld_by_name <- function(name_regex) {
  hifld %>%
    filter(str_detect(NAME, regex(name_regex, ignore_case = TRUE)))
}

# ---- 4. Build crosswalk: one row per (subsidiary, tract) --------------------

message("Building crosswalk for ", nrow(targets), " subsidiaries...")

crosswalk_list <- list()

for (i in seq_len(nrow(targets))) {
  sub <- targets[i, ]
  matched_territories <- match_hifld_by_name(sub$name_regex)

  if (nrow(matched_territories) == 0) {
    message("  [WARN] No HIFLD features matched for: ", sub$subsidiary_label)
    next
  }

  # Union territories for this subsidiary to get one polygon
  territory_union <- matched_territories %>%
    st_union() %>%
    st_make_valid()

  # Find tract centroids within the union polygon
  within_idx <- suppressWarnings(
    st_within(tract_centroids, territory_union, sparse = TRUE)
  )
  in_territory <- lengths(within_idx) > 0

  if (!any(in_territory)) {
    message("  [WARN] No tracts found within territory for: ", sub$subsidiary_label)
    next
  }

  tracts_in <- tracts[in_territory, ]

  # Record which HIFLD feature_id each tract sits in (use individual polygons,
  # not the union, so we preserve feature-level traceability)
  within_features <- suppressWarnings(
    st_within(tract_centroids[in_territory, ], matched_territories, sparse = TRUE)
  )
  hifld_ids <- map_chr(within_features, function(idx) {
    if (length(idx) == 0) return(NA_character_)
    paste(matched_territories$hifld_feature_id[idx], collapse = ";")
  })

  crosswalk_list[[i]] <- tibble(
    target_holding_co = sub$target_holding_co,
    subsidiary_label  = sub$subsidiary_label,
    expected_states   = sub$expected_states,
    tract_geoid       = tracts_in$GEOID,
    hifld_feature_id  = hifld_ids
  )

  message("  ", sub$subsidiary_label, ": ", nrow(tracts_in), " tracts")
}

crosswalk <- bind_rows(crosswalk_list)

message("\nCrosswalk built: ", nrow(crosswalk), " rows (subsidiary × tract)")
message("Unique tracts: ", n_distinct(crosswalk$tract_geoid))
message("Unique holding companies: ", n_distinct(crosswalk$target_holding_co))

# ---- 5. Coverage sanity check -----------------------------------------------

coverage_check <- crosswalk %>%
  count(target_holding_co, name = "n_tracts") %>%
  arrange(n_tracts)

message("\nTract counts by holding company:")
print(coverage_check, n = Inf)

low_coverage <- coverage_check %>% filter(n_tracts < 1000)
if (nrow(low_coverage) > 0) {
  message("\n[WARN] The following targets have fewer than 1,000 tracts:")
  print(low_coverage, n = Inf)
}

# ---- 6. Write output --------------------------------------------------------

out_path <- glue("outputs/{format(Sys.Date(), '%d-%m-%Y')}-utility-tract-crosswalk.csv")
write.csv(crosswalk, out_path, row.names = FALSE)
message("\nCrosswalk written to: ", out_path)
