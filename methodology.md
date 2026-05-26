# Methodology — United Ratepayers Strategy Convening 2026

## Purpose

This document explains, in plain language, how the United Ratepayers 2026 comparative analysis was built. It is written for energy advocates, legal staff, and communications teams who need to understand and cite the findings without necessarily reading the underlying R code. For full data-source citations — including URLs, variable names, local file paths, and version notes — see `README.md`, which is the authoritative source of record for all inputs.

---

## What We Measured (the Four Metrics)

1. **Annual profits and profit growth.** Net income for each utility in FY2021, FY2024, and FY2025, expressed in millions of dollars. Growth is reported as a ratio (e.g., 2× growth = profits doubled) over two horizons: FY2024→FY2025 (one year) and FY2021→FY2025 (four years).

2. **CEO total compensation.** The total pay package — salary, bonus, stock awards, and other compensation — for the chief executive of the relevant holding company, drawn from the most recent proxy filing available.

3. **Residential energy burden.** The share of household income that a typical residential customer spends on energy (electricity + gas + other fuels). Reported as a weighted mean, a weighted median, and the share of households above 6% — the widely used threshold for "high" energy burden.

4. **Shutoffs for non-payment.** The number of residential accounts disconnected for non-payment in the most recent calendar year for which complete data are available, where reported.

---

## The Ten Utilities

The ten target utilities are listed in full in the Target Utilities table in `README.md`. Two overlaps are worth noting here in plain language:

- **ComEd and Exelon** are both in the analysis. ComEd is an operating subsidiary of Exelon. Profits and CEO compensation are reported at the Exelon holding-company level; energy burden and shutoff data are at the ComEd operating level, because those metrics depend on which customers ComEd actually serves. Both rows are kept so the analysis can speak to ComEd's service territory specifically while also capturing Exelon's full consolidated finances.

- **APS and Pinnacle West** follow the same logic. Arizona Public Service Company (APS) is the operating subsidiary; Pinnacle West Capital is the holding company. Financial metrics are at the Pinnacle West level; energy burden data is at the APS level.

---

## Data Sources at a Glance

| Source | What it gives us | Where in the pipeline | Full detail |
|--------|-----------------|----------------------|-------------|
| Energy and Policy Institute (EPI) | Utility net income (2021, 2024, 2025) and CEO total compensation | Scripts 01, 02 | README — Financial Data section |
| Energy Justice Lab (EJL) Disconnection Dashboard | Annual residential shutoffs for non-payment | Script 03 | README — Shutoffs section |
| American Community Survey (ACS) B19013, 2022 + 2024 | Tract-level median household income | Script 04 | README — ACS section |
| HIFLD Electric Retail Service Territories | Utility service territory polygons | Script 05 | README — GIS / HIFLD section |
| Census 2022 Cartographic Boundary Tracts | Census tract polygons for centroid mapping | Script 06 | README — Census Tract Boundaries section |
| DOE LEAD 2022 | Tract-level energy burden baseline (2022) | Script 07 | README — DOE LEAD section |
| EIA Form 861 | Residential electricity revenue and customers by utility (2022, 2024) | Script 07 | README — EIA 861 section |
| EIA Form 176 | Average annual residential gas bill by state (2022, 2024) | Script 07 | README — EIA 176 section |

---

## Methods

### Part A — Financial Metrics (Scripts 01 and 02)

**Data source:** Energy and Policy Institute (EPI) datasets, which compile annual net income and CEO compensation from SEC 10-K and DEF 14A (proxy) filings.

**Profits (Script 02, `R/02_epi_utility_profits.R`):** For each of the ten target holding companies, the script sums subsidiary-level net income across all subsidiaries reported under that parent for FY2021, FY2024, and FY2025. Growth ratios are then computed arithmetically (2025 value ÷ 2024 value for the one-year ratio; 2025 value ÷ 2021 value for the four-year ratio).

**CEO compensation (Script 01, `R/01_epi_exec_comp.R`):** The script extracts total compensation for the most recent proxy year available for each holding company's chief executive.

**Holding-company vs. operating-utility level.** ComEd's profits are pulled at the ComEd operating-utility level (not Exelon's consolidated total), because the convening wants to see ComEd's own earnings. ComEd's CEO compensation, however, is pulled at the Exelon level, because Exelon's CEO is ComEd's ultimate executive and that is how compensation is disclosed publicly. The same pattern applies to APS / Pinnacle West.

**Known gaps:**
- National Grid's 2025 profit data are not available in the EPI dataset. FY2021 and FY2024 figures are reported; FY2025 profit and the one-year growth ratio are left blank.
- El Paso Electric has been privately held since 2020 (acquired by Infrastructure Investment Fund). It does not file public financial disclosures, so both profit and CEO compensation are unavailable.

---

### Part B — Shutoffs for Non-Payment (Script 03)

**Data source:** Energy Justice Lab (EJL) Utility Disconnection Dashboard. The EJL dataset specifically tracks disconnections for non-payment — it does not include disconnections for other reasons such as customer moves or safety shutoffs.

**Year selection (Script 03, `R/03_ejl_disconnections.R`):** For each combination of utility, state, and service type (electric or gas), the script identifies the most recent calendar year for which all twelve months are reported in the EJL data. If no complete year exists for a given combination, that combination is excluded.

**Double-counting prevention:** The EJL data contains, for PECO (Exelon) and Xcel Energy (Colorado), both separate electric and gas rows and a combined "Electric and Gas Customers" row. The combined rows are excluded before matching to prevent double-counting.

**Coverage gaps:** SWEPCO, PSO, Pepco, Atlantic City Electric, Alabama Power, and Mississippi Power are not reported in the EJL data and therefore have no shutoff figures in the final output.

---

### Part C — Energy Burden (Scripts 04–08)

Energy burden is the share of a household's annual income spent on energy costs — electricity, natural gas, and other fuels such as heating oil and propane. A burden above 6% is widely considered "high" or "unaffordable" in U.S. energy-equity research. The 6% threshold is used by both DOE LEAD and the National Energy Assistance Directors' Association as the upper bound of affordable energy spending.

#### C1. Why This Is Hard

The most authoritative tract-level energy burden data come from the Department of Energy's Low-Income Energy Affordability Data (LEAD) Tool. DOE LEAD gives us detailed, household-weighted estimates for every census tract in the country — but only for 2022. We need 2024 figures that reflect more recent utility rate increases and income changes.

DOE LEAD also does not identify which utility company serves each census tract. So before we can produce per-utility burden statistics, we need to build a geographic link between each utility's service territory and the census tracts inside it.

These two challenges — the vintage gap and the missing utility-to-tract link — are why the energy burden pipeline spans five scripts (04–08) rather than a single step.

#### C2. Mapping Utilities to Neighborhoods (Scripts 05 and 06)

**Script 05 (`R/05_territory_coverage.R`)** matches each of the ten target holding companies' operating subsidiaries to one or more electric service territory polygons in the HIFLD dataset (Electric Retail Service Territories, published by the Oak Ridge National Laboratory). Each match is based on utility name, and the script confirms that all 34 expected operating subsidiaries matched at least one polygon.

**Script 06 (`R/06_utility_tract_crosswalk.R`)** builds the utility-to-tract link using a technique called centroid-in-polygon. The geographic center — or **centroid** — of each census tract is computed, and then the script checks whether that centroid falls inside each utility's service territory polygon. If it does, the tract is assigned to that utility.

**Why centroids?** This approach is simple, deterministic, and matches the geographic unit DOE LEAD uses for its own reporting. The main limitation is that tracts straddling a service territory boundary are assigned to whichever territory contains their centroid. A tract whose centroid falls just outside a territory boundary will be excluded from that utility's count even if a portion of the tract's population is served by that utility. This limitation is most material for large, sparsely populated rural tracts at the edge of a service territory; for dense urban tracts, it is negligible.

**ComEd/Exelon overlap:** Census tracts assigned to ComEd's service territory are counted in both ComEd's row and Exelon's row in the final output. This is intentional — the convening wants to see ComEd's service territory specifically while also seeing Exelon's full service footprint.

**Output (the crosswalk):** A table linking every operating subsidiary to every census tract whose centroid falls within its territory — 32,739 rows across the ten holding companies.

#### C3. The 2022 Baseline (DOE LEAD)

DOE LEAD provides, for each census tract and each subpopulation within that tract, the following annual averages:

- **Average household income** (`avg_income`)
- **Average electricity cost** (`avg_electricity_cost`)
- **Average natural gas cost** (`avg_gas_cost`)
- **Average other fuel cost** (`avg_other_fuel_cost`) — covers heating oil, propane, wood, and similar fuels
- **Valid-units counts** — the number of households each cost estimate represents, reported separately for income, electricity, gas, and other fuels (`hincp_valid_units`, `elep_valid_units`, `gasp_valid_units`, `fulp_valid_units`)

The subpopulations are defined by combinations of income band, tenure (owner vs. renter), building age, and primary heating fuel. A single census tract can have dozens of rows — one per subpopulation. The pipeline preserves this granularity so that weighted statistics downstream reflect the actual mix of household types within each tract.

**ACS tract median income (Script 04, `R/04_acs_tract_median_income.R`)** downloads 2022 and 2024 median household income for each census tract in the 34 target states from the American Community Survey (ACS) Table B19013, via the Census Bureau API. These figures are used in the next step to compute how much tract incomes changed between 2022 and 2024.

#### C4. Forward-Projecting to 2024 (Script 07)

Script 07 (`R/07_burden_estimates_2024.R`) takes each DOE LEAD subpopulation row and applies three multiplicative growth ratios to convert the 2022 baseline figures to 2024 estimates.

| Cost component | Growth ratio source | Geographic resolution of the ratio |
|---------------|--------------------|------------------------------------|
| Household income | ACS B19013 (2024 ÷ 2022 tract median income) | Census tract |
| Electricity bill | EIA Form 861 (2024 ÷ 2022 residential revenue per customer) | Operating utility × state |
| Natural gas bill | EIA Form 176 (2024 ÷ 2022 average residential gas bill) | State |
| Other fuels | Not projected — held at 2022 value | n/a |

Each ratio is a simple scalar: a value of 1.15 means costs grew 15% between 2022 and 2024. The script multiplies the 2022 baseline figure by the appropriate ratio to get the 2024 estimate. This is not a statistical model — it is a scaling operation that applies observed aggregate growth to the household-level baseline.

The 2024 per-row energy burden is then computed as:

> burden\_2024 = (electricity\_2024 + gas\_2024 + other\_fuel\_2024) ÷ income\_2024

**Why this hybrid approach:** DOE LEAD has not released a 2024 vintage of its data, so we cannot simply re-download updated figures. Forward-projecting at the most granular level each source supports — tract-level for income, utility-level for electricity, state-level for gas — gives us 2024 estimates that capture both local income trends and utility-specific rate changes. This is more precise than applying a single national growth factor, while being transparent about where the granularity runs out.

**Missing ratios:** If a growth ratio cannot be computed for a particular utility × state or state combination (for example, because the utility is not present in EIA 861 for a given year), the ratio defaults to 1.0 — meaning no change is assumed. This is a conservative choice: it prevents fabricating an estimate from nothing, but may understate burden growth for the affected utility.

#### C5. Aggregating to Per-Utility Statistics (Script 08)

Script 08 (`R/08_burden_summary.R`) joins the 2024 burden estimates to the utility-tract crosswalk and computes three summary statistics for each of the ten targets:

1. **Weighted mean burden.** Each cost component is weighted by its own valid-units count (the number of households that component's estimate represents), the weighted components are summed, and the total is divided by weighted income. This is more precise than a simple average because it accounts for the fact that not every household has data recorded for every energy component.

2. **Weighted median burden.** The median row-level burden, weighted by the number of households represented. The median is more robust to outliers than the mean; this matters because ACS tract-level income estimates can be noisy for small or sparse tracts.

3. **Share above 6%.** The fraction of households in the service territory whose estimated 2024 energy burden exceeds 6%. Calculated as the count of households in rows where `burden_2024 > 0.06` divided by the total count of households with a valid burden estimate.

---

## Key Assumptions and Limitations

- **Other fuels held at 2022.** No reliable national source provides a utility- or state-level growth ratio for heating oil, propane, or wood between 2022 and 2024. Other fuel costs are therefore left at their 2022 values. This assumption may understate energy burden for households in the rural Northeast and rural West, where heating oil and propane are common primary heating fuels.

- **Missing ratios default to 1.0.** When an electricity or gas growth ratio cannot be matched to a specific utility × state or state, no scaling is applied (the 2024 estimate equals the 2022 baseline for that component). This is conservative — burden growth for unmatched utilities is neither overstated nor fabricated, but may be understated.

- **Centroid-in-polygon.** Census tracts are assigned to a utility's territory based on whether the tract's geographic center falls within the territory polygon. Tracts whose centroid falls outside a territory boundary are excluded, even if part of the tract's population is inside the boundary. This is most consequential for large rural tracts at territory edges; for most urban and suburban tracts it introduces negligible error.

- **HIFLD shapefile vintage (August 2023).** The service territory polygons reflect utility ownership as of the shapefile's publication date. Notably, National Grid sold Narragansett Electric (Rhode Island) to PPL in 2022; the shapefile still attributes that territory to National Grid. Narragansett Electric's tracts are therefore included in National Grid's burden statistics, which may slightly inflate National Grid's burden figures.

- **ACS noise at the tract level.** American Community Survey estimates for small census tracts carry meaningful margins of error, especially for income. The income growth ratios derived from ACS B19013 range from 0.25 to 6.11 across tracts in the dataset, reflecting both genuine local trends and statistical noise. Using weighted statistics (weighted mean and weighted median) dampens the effect of noisy extreme values but does not eliminate it.

- **The 6% threshold is a convention, not a statute.** The 6% high-burden threshold is widely used in energy-equity research and by DOE LEAD itself, but it is not a regulatory or legal standard. Alternative threshold analyses (e.g., 3% / 6% / 10% bands, or different thresholds for low-income households) can be computed from the detailed output CSV produced by Script 08 if needed.

- **No demographic disaggregation.** The summary statistics reported in the final CSV are population-weighted averages across all households in each utility's service territory. The underlying DOE LEAD subpopulation data support breakdowns by income band, tenure (owner vs. renter), and heating fuel if a more disaggregated analysis is needed.

---

## Glossary

**Census tract.** A small, relatively stable geographic unit used by the Census Bureau to collect and publish demographic data. Census tracts typically contain 1,200 to 8,000 people. The United States is divided into roughly 85,000 tracts.

**Centroid.** The geographic center of a polygon — in this case, the center point of a census tract's boundary. Used here to assign each tract to a utility service territory.

**Energy burden.** The share of a household's annual income spent on residential energy costs (electricity, natural gas, and other fuels). Expressed as a decimal (e.g., 0.08 = 8%) or a percentage.

**High energy burden.** An energy burden above 6% of household income. A household spending more than 6% of its income on energy is considered to face unaffordable energy costs under the DOE LEAD framework and the National Energy Assistance Directors' Association standard.

**Operating subsidiary.** A utility company that directly provides service to customers — for example, ComEd (electricity in northern Illinois) or Pacific Gas & Electric. An operating subsidiary is often owned by a larger **holding company** (e.g., Exelon owns ComEd; PG&E Corporation owns Pacific Gas & Electric).

**Holding company.** A parent corporation that owns one or more operating utilities but does not itself provide service to customers. Holding companies file consolidated financial reports with the SEC and typically disclose CEO compensation at the holding-company level.

**Valid units.** In DOE LEAD, the number of households (survey respondents) whose data were used to compute an average for a given tract × subpopulation × cost component. Valid-units counts serve as weights in downstream aggregation: a row representing 500 households contributes more to a weighted average than a row representing 10 households.

**Growth ratio.** A multiplicative scalar computed as a later-year value divided by an earlier-year value. A growth ratio of 1.12 means costs grew by 12%. Applied by multiplying the baseline figure by the ratio. This is not a statistical estimate — it is a straightforward scaling of observed aggregate trends.

---

## Source-Code Reference

| Script | Purpose |
|--------|---------|
| `R/lib/target_subsidiaries.R` | Defines the list of ten target holding companies and their operating subsidiaries; imported by all downstream scripts |
| `R/01_epi_exec_comp.R` | Extracts CEO total compensation from EPI data for each holding company |
| `R/02_epi_utility_profits.R` | Aggregates subsidiary-level net income into holding-company totals for FY2021, FY2024, and FY2025; computes growth ratios |
| `R/03_ejl_disconnections.R` | Extracts annual shutoffs for non-payment from the EJL Disconnection Dashboard |
| `R/04_acs_tract_median_income.R` | Downloads 2022 and 2024 ACS B19013 tract median household income for 34 states via the Census API |
| `R/05_territory_coverage.R` | Matches target operating subsidiaries to HIFLD service territory polygons; produces coverage gap report |
| `R/06_utility_tract_crosswalk.R` | Assigns census tracts to operating subsidiaries via centroid-in-polygon; produces the utility-tract crosswalk |
| `R/07_burden_estimates_2024.R` | Joins DOE LEAD 2022 baseline to the crosswalk, applies income/electricity/gas growth ratios, computes 2024 per-row burden |
| `R/08_burden_summary.R` | Aggregates 2024 burden estimates to per-utility weighted mean, weighted median, and share above 6% |
