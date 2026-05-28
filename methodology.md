# Methodology — United Ratepayers Strategy Convening 2026

## Purpose

This document explains, in plain language, how the United Ratepayers 2026 comparative analysis was built. It is written for energy advocates, legal staff, and communications teams who need to understand and cite the findings without necessarily reading the underlying R code. For full data-source citations — including URLs, variable names, local file paths, and version notes — see `README.md`, which is the authoritative source of record for all inputs.

---

## What We Measured (the Four Metrics)

1. **Annual profits and profit growth.** Net income for each utility in FY2021, FY2024, and FY2025, expressed in millions of dollars. Growth is reported as a ratio (e.g., 2× growth = profits doubled) over two horizons: FY2024→FY2025 (one year) and FY2021→FY2025 (four years).

2. **CEO total compensation.** The total pay package — salary, bonus, stock awards, and other compensation — for the chief executive of the relevant holding company, drawn from the most recent proxy filing available.

3. **Residential energy burden.** The share of household income that a typical residential customer spends on energy (electricity + gas + other fuels). Reported as a weighted mean, a weighted median, and the share of households above 6% — the widely used threshold for "high" energy burden.

4. **Shutoffs for non-payment.** The number of residential accounts disconnected for non-payment in the most recent calendar year for which complete data are available, where reported.

5. **Service territory size.** The number of residential electric customers and residential gas customers each utility serves, drawn from the most recent year of federal reporting (2024). These counts give the other four metrics scale: a $1B profit at a utility serving 7 million households reads very differently than a $1B profit at a utility serving 400,000.

---

## The Twelve Utilities

The twelve target utilities are listed in full in the Target Utilities table in `README.md`. Three overlaps are worth noting here in plain language:

- **ComEd and Exelon** are both in the analysis. ComEd is an operating subsidiary of Exelon. Profits and CEO compensation are reported at the Exelon holding-company level; energy burden and shutoff data are at the ComEd operating level, because those metrics depend on which customers ComEd actually serves. Both rows are kept so the analysis can speak to ComEd's service territory specifically while also capturing Exelon's full consolidated finances.

- **APS and Pinnacle West** follow the same logic. Arizona Public Service Company (APS) is the operating subsidiary; Pinnacle West Capital is the holding company. Financial metrics are at the Pinnacle West level; energy burden data is at the APS level.

- **NV Energy and Berkshire Hathaway Energy** follow the same pattern, with one extra layer. NV Energy is a trade name for two operating utilities — Nevada Power Company (southern Nevada) and Sierra Pacific Power Company (northern Nevada, plus a sliver of eastern California). Both are wholly owned by Berkshire Hathaway Energy (BHE). BHE itself is roughly 92% owned by Berkshire Hathaway Inc., Warren Buffett's holding conglomerate, but BHE files its own SEC reports because it has registered public debt — so its CEO compensation and consolidated net income are disclosed at the BHE level (Gregory Abel). NV Energy does not file its own proxy, so its CEO compensation row pulls from BHE just as APS's row pulls from Pinnacle West. Energy burden and customer-count metrics for NV Energy are reported at the Nevada Power + Sierra Pacific operating level. The BHE row rolls up NV Energy plus two other U.S. retail subsidiaries — PacifiCorp (operating as Pacific Power in OR/WA/CA and as Rocky Mountain Power in UT/WY/ID) and MidAmerican Energy (IA/IL/SD/NE). BHE's UK distribution business (Northern Powergrid) and its interstate gas-transmission businesses (BHE Pipeline Group, BHE GT&S) are out of scope; we limit the BHE rollup to retail electric and gas distribution to keep the comparison apples-to-apples with the other targets.

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
| EIA Form 861 | Residential electricity revenue and customers by utility (2022, 2024) | Script 07 (growth ratio) and Script 09 (customer counts) | README — EIA 861 section |
| EIA Form 176 (state level) | Average annual residential gas bill by state (2022, 2024) | Script 07 | README — EIA 176 section |
| EIA Form 176 via PUDL (utility level) | Residential gas customer counts by utility × state (2024) | Script 09 | `Cleaned_Data/pudl/eia/176/CLEANED.md` |

---

## Methods

### Part A — Financial Metrics (Scripts 01 and 02)

**Data source:** Energy and Policy Institute (EPI) datasets, which compile annual net income and CEO compensation from SEC 10-K and DEF 14A (proxy) filings.

**Profits (Script 02, `R/02_epi_utility_profits.R`):** For each of the twelve target holding companies, the script sums subsidiary-level net income across all subsidiaries reported under that parent for FY2021, FY2024, and FY2025. Growth ratios are then computed arithmetically (2025 value ÷ 2024 value for the one-year ratio; 2025 value ÷ 2021 value for the four-year ratio).

**CEO compensation (Script 01, `R/01_epi_exec_comp.R`):** The script extracts total compensation for the most recent proxy year available for each holding company's chief executive.

**Holding-company vs. operating-utility level.** ComEd's profits are pulled at the ComEd operating-utility level (not Exelon's consolidated total), because the convening wants to see ComEd's own earnings. ComEd's CEO compensation, however, is pulled at the Exelon level, because Exelon's CEO is ComEd's ultimate executive and that is how compensation is disclosed publicly. The same pattern applies to APS / Pinnacle West, and to NV Energy / Berkshire Hathaway Energy: NV Energy's profits are summed from its Nevada Power and Sierra Pacific Power operating rows, while its CEO compensation comes from Gregory Abel at the BHE parent (NV Energy operating CEO Brandon Barkhuff's compensation is not separately disclosed). BHE itself is reported as its own holding-company row, with net income summed across NV Energy + PacifiCorp + MidAmerican.

**Known gaps:**
- National Grid's 2025 profit data are not available in the EPI dataset. FY2021 and FY2024 figures are reported; FY2025 profit and the one-year growth ratio are left blank.
- El Paso Electric has been privately held since 2020 (acquired by Infrastructure Investment Fund). It does not file public financial disclosures, so both profit and CEO compensation are unavailable.

---

### Part B — Shutoffs for Non-Payment (Script 03)

**Data source:** Energy Justice Lab (EJL) Utility Disconnection Dashboard. The EJL dataset specifically tracks disconnections for non-payment — it does not include disconnections for other reasons such as customer moves or safety shutoffs.

**Year selection (Script 03, `R/03_ejl_disconnections.R`):** For each combination of utility, state, and service type (electric or gas), the script identifies the most recent calendar year for which all twelve months are reported in the EJL data. If no complete year exists for a given combination, that combination is excluded.

**Double-counting prevention:** The EJL data contains, for PECO (Exelon) and Xcel Energy (Colorado), both separate electric and gas rows and a combined "Electric and Gas Customers" row. The combined rows are excluded before matching to prevent double-counting.

**Coverage gaps:** SWEPCO, PSO, Pepco, Atlantic City Electric, Alabama Power, and Mississippi Power are not reported in the EJL data and therefore have no shutoff figures in the final output. Neither Nevada Power Company nor Sierra Pacific Power Company appears in EJL either, so NV Energy's disconnection cell is blank. Berkshire Hathaway Energy's disconnection total reflects only the BHE subsidiaries EJL does cover (MidAmerican Energy IA/IL, PacifiCorp, Pacific Power, Rocky Mountain Power); the NV Energy portion of BHE's rollup contributes nothing to that figure.

---

### Part C — Energy Burden (Scripts 04–08)

Energy burden is the share of a household's annual income spent on energy costs — electricity, natural gas, and other fuels such as heating oil and propane. A burden above 6% is widely considered "high" or "unaffordable" in U.S. energy-equity research. The 6% threshold is used by both DOE LEAD and the National Energy Assistance Directors' Association as the upper bound of affordable energy spending.

#### C1. Why This Is Hard

The most authoritative tract-level energy burden data come from the Department of Energy's Low-Income Energy Affordability Data (LEAD) Tool. DOE LEAD gives us detailed, household-weighted estimates for every census tract in the country — but only for 2022. We need 2024 figures that reflect more recent utility rate increases and income changes.

DOE LEAD also does not identify which utility company serves each census tract. So before we can produce per-utility burden statistics, we need to build a geographic link between each utility's service territory and the census tracts inside it.

These two challenges — the vintage gap and the missing utility-to-tract link — are why the energy burden pipeline spans five scripts (04–08) rather than a single step.

#### C2. Mapping Utilities to Neighborhoods (Scripts 05 and 06)

**Script 05 (`R/05_territory_coverage.R`)** matches each of the twelve target holding companies' operating subsidiaries to one or more electric service territory polygons in the HIFLD dataset (Electric Retail Service Territories, published by the Oak Ridge National Laboratory). Each match is based on utility name, and the script confirms that all 41 expected operating subsidiaries matched at least one polygon.

**Script 06 (`R/06_utility_tract_crosswalk.R`)** builds the utility-to-tract link using a technique called centroid-in-polygon. The geographic center — or **centroid** — of each census tract is computed, and then the script checks whether that centroid falls inside each utility's service territory polygon. If it does, the tract is assigned to that utility.

**Why centroids?** This approach is simple, deterministic, and matches the geographic unit DOE LEAD uses for its own reporting. The main limitation is that tracts straddling a service territory boundary are assigned to whichever territory contains their centroid. A tract whose centroid falls just outside a territory boundary will be excluded from that utility's count even if a portion of the tract's population is served by that utility. This limitation is most material for large, sparsely populated rural tracts at the edge of a service territory; for dense urban tracts, it is negligible.

**ComEd/Exelon overlap:** Census tracts assigned to ComEd's service territory are counted in both ComEd's row and Exelon's row in the final output. This is intentional — the convening wants to see ComEd's service territory specifically while also seeing Exelon's full service footprint. The same convention applies to NV Energy / Berkshire Hathaway Energy: Nevada Power and Sierra Pacific Power tracts are counted both under NV Energy and under BHE.

**Output (the crosswalk):** A table linking every operating subsidiary to every census tract whose centroid falls within its territory — 36,026 rows across the twelve holding companies.

#### C3. The 2022 Baseline (DOE LEAD)

DOE LEAD provides, for each census tract and each subpopulation within that tract, the following annual averages:

- **Average household income** (`avg_income`)
- **Average electricity cost** (`avg_electricity_cost`)
- **Average natural gas cost** (`avg_gas_cost`)
- **Average other fuel cost** (`avg_other_fuel_cost`) — covers heating oil, propane, wood, and similar fuels
- **Valid-units counts** — the number of households each cost estimate represents, reported separately for income, electricity, gas, and other fuels (`hincp_valid_units`, `elep_valid_units`, `gasp_valid_units`, `fulp_valid_units`)

The subpopulations are defined by combinations of income band, tenure (owner vs. renter), building age, and primary heating fuel. A single census tract can have dozens of rows — one per subpopulation. The pipeline preserves this granularity so that weighted statistics downstream reflect the actual mix of household types within each tract.

**ACS tract median income (Script 04, `R/04_acs_tract_median_income.R`)** downloads 2022 and 2024 median household income for each census tract in the 42 target states from the American Community Survey (ACS) Table B19013, via the Census Bureau API. (The 2026 expansion added NV for NV Energy, OR/WA/UT/WY/ID for PacifiCorp, and IA/NE for MidAmerican Energy; California and South Dakota were already in the collection.) These figures are used in the next step to compute how much tract incomes changed between 2022 and 2024.

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

Script 08 (`R/08_burden_summary.R`) joins the 2024 burden estimates to the utility-tract crosswalk and computes three summary statistics for each of the twelve targets:

1. **Weighted mean burden.** Each cost component is weighted by its own valid-units count (the number of households that component's estimate represents), the weighted components are summed, and the total is divided by weighted income. This is more precise than a simple average because it accounts for the fact that not every household has data recorded for every energy component.

2. **Weighted median burden.** The median row-level burden, weighted by the number of households represented. The median is more robust to outliers than the mean; this matters because ACS tract-level income estimates can be noisy for small or sparse tracts.

3. **Share above 6%.** The fraction of households in the service territory whose estimated 2024 energy burden exceeds 6%. Calculated as the count of households in rows where `burden_2024 > 0.06` divided by the total count of households with a valid burden estimate.

---

### Part D — Service Territory Customer Counts (Script 09)

#### D1. Why customer counts matter to the comparison

The four metrics in Parts A–C describe what each utility earns, what it pays its chief executive, how heavy its customers' energy bills are, and how many of those customers are cut off for non-payment. None of those numbers is meaningful in isolation: a half-million-dollar disconnection figure means one thing for a utility serving four million households and another thing entirely for a utility serving four hundred thousand. Part D adds the denominator — how many households the utility actually serves — so every other metric in the deliverable can be read at the right scale.

#### D2. Residential electric customers (EIA Form 861)

**Source.** EIA Form 861 is the U.S. Department of Energy's annual survey of every electric utility in the country. It records how many customers each utility serves, broken out by class (residential, commercial, industrial) and by the state in which they take service. We use the 2024 reporting year — the most recent available at the time of analysis.

**Method.** For each of the twelve target utilities, the script identifies that utility's operating subsidiaries using the same name patterns established in Scripts 05 through 07 (kept in one shared file, `R/lib/target_subsidiaries.R`, so every script in the pipeline agrees on which entities roll up to which holding company). Within EIA 861, a single operating company can appear more than once in the same state if it files different parts of the form separately; the script deduplicates on utility-and-state before summing residential customers, to make sure no household is counted twice.

**ComEd appears in two rows on purpose.** As with the energy-burden analysis, ComEd's customer count is included in both the ComEd row and the Exelon row of the final summary. This is consistent with the rest of the deliverable: the convening wants to see ComEd's service-territory scale on its own as well as Exelon's full consolidated footprint. NV Energy and Berkshire Hathaway Energy follow the same convention: Nevada Power Co. and Sierra Pacific Power Co. residential customers are counted in both rows.

**Caveat — Community Choice Aggregation.** California (and a handful of other states) have a program in which a locally governed Community Choice Aggregator buys generation on behalf of residents while the incumbent utility continues to deliver the electricity. The CCA, not the incumbent utility, files the EIA 861 row for those customers' residential count. PG&E's reported figure (about 1.86 million residential customers) therefore reflects only its directly-bundled customers; the company actually delivers electricity to several million additional households whose generation is now served by a CCA. PG&E's per-customer profit, pay, and burden numbers should be compared cautiously against vertically integrated utilities in states without CCAs.

#### D3. Residential gas customers (EIA Form 176 via PUDL)

**Source.** EIA Form 176 is the federal natural gas operator survey, the gas-side counterpart to Form 861. Catalyst Cooperative's Public Utility Data Liberation (PUDL) project republishes Form 176 in a clean, utility-level form. We use the PUDL extract for the 2024 reporting year and filter to residential customers.

**Method.** Eight of the twelve target utilities operate gas distribution subsidiaries in addition to their electric business: Duke Energy, Exelon, National Grid, PG&E, Xcel Energy, Southern Company, NV Energy, and Berkshire Hathaway Energy. For each of those eight, the script aggregates the residential customer counts of every named gas subsidiary in the PUDL data — for example, Southern Company's gas customer figure sums Atlanta Gas Light, Nicor Gas (Illinois), Virginia Natural Gas, and Chattanooga Gas. NV Energy's gas customers come from Sierra Pacific Power Company, which operates a gas distribution business in the Reno/Sparks area (Nevada Power Co. is electric-only, and Southwest Gas — independent of NV Energy — serves Las Vegas-area gas customers). Berkshire Hathaway Energy's gas rollup adds MidAmerican Energy Company's gas customers (heavily concentrated in Iowa, with smaller footprints in IL/NE/SD) on top of Sierra Pacific. PacifiCorp is electric-only. The remaining four target utilities (American Electric Power, ComEd as a stand-alone row, Arizona Public Service, and El Paso Electric) do not operate gas distribution, so their gas customer count is blank rather than zero.

**Two different views of EIA 176.** A note on naming: Script 07 uses a state-level version of EIA 176 for the gas-bill growth ratio that projects 2022 burden figures forward to 2024. Script 09 uses a utility-level version of the same underlying federal survey, accessed via PUDL. Both pull from EIA Form 176; they differ only in how the data are aggregated — state totals for Script 07's projection, utility-by-utility for Script 09's customer counts.

#### D4. Final assembly (Script 09)

Script 09 (`R/09_final_summary.R`) is the last step in the pipeline. It joins the four upstream outputs — CEO compensation (Script 01), utility profits (Script 02), shutoffs (Script 03), and energy burdens (Script 08) — with the electric and gas customer-count tables built in D2 and D3, producing a single 12-row, 14-column comparative table. Two files are written: a CSV that follows the rest of the repo's naming convention for downstream pipelines, and a formatted Excel workbook intended for sharing at the convening. The Excel workbook has two sheets:

- **Summary** — the 14-column table with column groups across the top (Identity, CEO compensation, Net income FY2025, Energy burdens, Disconnections, Customer counts 2024), dollar / percent / comma formatting on the values, a frozen header, and column widths set so every cell is legible without resizing.
- **Methodology** — a condensed in-workbook reference describing every column and its data source, so a reader who opens the Excel without the larger repo can still cite each figure correctly.

---

### Part E — CEO Pay Ranking and Profit-Change Reporting

Two of the columns in the final deliverable are derived inside Script 09 rather than carried over directly from Scripts 01 or 02. Both are worth describing in plain language because each makes a non-obvious choice about how to present the underlying data.

**CEO pay ranking.** The deliverable includes a numeric rank for each target utility's CEO compensation — rank 1 is the highest-paid CEO, rank 2 the next highest, and so on. The ranking is computed against the *entire* EPI executive-compensation universe (roughly 51 utilities after deduplicating to one row per utility, keeping the highest-paid named executive as the incumbent), not just the twelve convening targets. This is a deliberate choice: ranking inside a self-selected group of twelve would always produce a 1-through-12 list, which says little about how the targets compare to the rest of the U.S. utility sector. Ranking against the EPI universe lets the convening say "this CEO is the *N*th-highest-paid utility chief executive in EPI's 2025 dataset," which is a sharper comparison. Three target utilities are not in the EPI universe: National Grid (UK-listed, files in London), Arizona Public Service (its holding company Pinnacle West is the EPI entity, not APS itself), and El Paso Electric (privately held since 2020). Their CEO rank is blank rather than placed at the bottom. NV Energy and Berkshire Hathaway Energy share Gregory Abel's rank — the same compensation figure is read off the BHE row for both targets, reflecting the operating-vs-parent reporting pattern described in "The Twelve Utilities."

**Profit change reporting.** Script 02 produces growth ratios — a value of 1.10 means profits grew 10%. Script 09 converts these into percent-change figures for display (a ratio of 1.10 becomes "+10.0%"). It also corrects a data-quality quirk in the EPI source: when EPI has not yet received a utility's FY2025 disclosure, it sometimes records the value as zero rather than as missing. Without intervention, the arithmetic of (zero ÷ prior year) − 1 would produce a misleading "−100%" figure for National Grid (whose UK fiscal-year calendar means 2025 data lags behind) and El Paso Electric (which no longer publishes). Script 09 treats those zeros as missing data, so those utilities show a blank in the profit-change columns rather than an inaccurate decline.

---

## Key Assumptions and Limitations

- **Other fuels held at 2022.** No reliable national source provides a utility- or state-level growth ratio for heating oil, propane, or wood between 2022 and 2024. Other fuel costs are therefore left at their 2022 values. This assumption may understate energy burden for households in the rural Northeast and rural West, where heating oil and propane are common primary heating fuels.

- **Missing ratios default to 1.0.** When an electricity or gas growth ratio cannot be matched to a specific utility × state or state, no scaling is applied (the 2024 estimate equals the 2022 baseline for that component). This is conservative — burden growth for unmatched utilities is neither overstated nor fabricated, but may be understated.

- **Centroid-in-polygon.** Census tracts are assigned to a utility's territory based on whether the tract's geographic center falls within the territory polygon. Tracts whose centroid falls outside a territory boundary are excluded, even if part of the tract's population is inside the boundary. This is most consequential for large rural tracts at territory edges; for most urban and suburban tracts it introduces negligible error.

- **HIFLD shapefile vintage (August 2023).** The service territory polygons reflect utility ownership as of the shapefile's publication date. Notably, National Grid sold Narragansett Electric (Rhode Island) to PPL in 2022; the shapefile still attributes that territory to National Grid. Narragansett Electric's tracts are therefore included in National Grid's burden statistics, which may slightly inflate National Grid's burden figures.

- **ACS noise at the tract level.** American Community Survey estimates for small census tracts carry meaningful margins of error, especially for income. The income growth ratios derived from ACS B19013 range from 0.25 to 6.11 across tracts in the dataset, reflecting both genuine local trends and statistical noise. Using weighted statistics (weighted mean and weighted median) dampens the effect of noisy extreme values but does not eliminate it.

- **The 6% threshold is a convention, not a statute.** The 6% high-burden threshold is widely used in energy-equity research and by DOE LEAD itself, but it is not a regulatory or legal standard. Alternative threshold analyses (e.g., 3% / 6% / 10% bands, or different thresholds for low-income households) can be computed from the detailed output CSV produced by Script 08 if needed.

- **No demographic disaggregation.** The summary statistics reported in the final CSV are population-weighted averages across all households in each utility's service territory. The underlying DOE LEAD subpopulation data support breakdowns by income band, tenure (owner vs. renter), and heating fuel if a more disaggregated analysis is needed.

- **PG&E electric customer count understates territory size.** PG&E delivers electricity to roughly five and a half million residential meters in northern and central California, but generation for the majority of those meters is now supplied by Community Choice Aggregators, which file their own EIA 861 row. The 1.86 million figure in the deliverable is PG&E's directly-bundled residential customers; its actual delivery footprint is substantially larger. Per-customer comparisons against vertically integrated utilities in states without CCA should be made with this in mind.

- **Narragansett (Rhode Island) is still grouped under National Grid.** PPL acquired Narragansett Electric from National Grid in May 2022. The repo's subsidiary mapping pre-dates that transfer and continues to attribute Narragansett to National Grid, so National Grid's gas customer count includes Narragansett's residential customers. This keeps the deliverable internally consistent with the burden statistics in Part C, which also attribute those tracts to National Grid; it does mean the reported National Grid customer figure is slightly inflated relative to today's ownership.

- **EIA Form 176 utility-level coverage depends on operator reporting.** A small gas distribution utility that did not file Form 176 for a given year, or that files under an unusual entity name, may be missed. The script targets each holding company's largest named gas subsidiaries by state; minor non-reporting affiliates are not captured.

- **CEO rank denominator is EPI's coverage, not the entire U.S. utility sector.** EPI tracks roughly 51 utilities after deduplication — predominantly the large investor-owned electric and gas companies plus a few select munis. A utility ranking, for example, twelfth means twelfth among the 51 utilities EPI compiles compensation data on, not twelfth in the country.

---

## Glossary

**Census tract.** A small, relatively stable geographic unit used by the Census Bureau to collect and publish demographic data. Census tracts typically contain 1,200 to 8,000 people. The United States is divided into roughly 85,000 tracts.

**Centroid.** The geographic center of a polygon — in this case, the center point of a census tract's boundary. Used here to assign each tract to a utility service territory.

**Community Choice Aggregator (CCA).** A locally governed organization — found in California, Massachusetts, New York, Illinois, New Jersey, Ohio, and a few other states — that purchases electricity generation on behalf of residents while leaving delivery in the hands of the incumbent utility. Because CCAs file their own EIA Form 861 row for generation customers, an incumbent utility's reported residential count can be substantially smaller than the number of homes to which it actually delivers electricity.

**Energy burden.** The share of a household's annual income spent on residential energy costs (electricity, natural gas, and other fuels). Expressed as a decimal (e.g., 0.08 = 8%) or a percentage.

**Energy and Policy Institute (EPI).** An independent watchdog organization that compiles annual executive-compensation and net-income figures from SEC filings into a single dataset covering the U.S. utility sector. The convening's primary source for both CEO pay and utility profits.

**High energy burden.** An energy burden above 6% of household income. A household spending more than 6% of its income on energy is considered to face unaffordable energy costs under the DOE LEAD framework and the National Energy Assistance Directors' Association standard.

**Operating subsidiary.** A utility company that directly provides service to customers — for example, ComEd (electricity in northern Illinois) or Pacific Gas & Electric. An operating subsidiary is often owned by a larger **holding company** (e.g., Exelon owns ComEd; PG&E Corporation owns Pacific Gas & Electric).

**Public Utility Data Liberation (PUDL).** A project of Catalyst Cooperative that republishes federal energy regulatory datasets in a clean, analysis-ready form. Used in this analysis to access utility-level natural gas customer counts from EIA Form 176, which the agency itself only publishes at the state level.

**Holding company.** A parent corporation that owns one or more operating utilities but does not itself provide service to customers. Holding companies file consolidated financial reports with the SEC and typically disclose CEO compensation at the holding-company level.

**Valid units.** In DOE LEAD, the number of households (survey respondents) whose data were used to compute an average for a given tract × subpopulation × cost component. Valid-units counts serve as weights in downstream aggregation: a row representing 500 households contributes more to a weighted average than a row representing 10 households.

**Growth ratio.** A multiplicative scalar computed as a later-year value divided by an earlier-year value. A growth ratio of 1.12 means costs grew by 12%. Applied by multiplying the baseline figure by the ratio. This is not a statistical estimate — it is a straightforward scaling of observed aggregate trends.

---

## Source-Code Reference

| Script | Purpose |
|--------|---------|
| `R/lib/target_subsidiaries.R` | Defines the list of twelve target holding companies and their operating subsidiaries; imported by all downstream scripts |
| `R/01_epi_exec_comp.R` | Extracts CEO total compensation from EPI data for each holding company |
| `R/02_epi_utility_profits.R` | Aggregates subsidiary-level net income into holding-company totals for FY2021, FY2024, and FY2025; computes growth ratios |
| `R/03_ejl_disconnections.R` | Extracts annual shutoffs for non-payment from the EJL Disconnection Dashboard |
| `R/04_acs_tract_median_income.R` | Downloads 2022 and 2024 ACS B19013 tract median household income for 42 states via the Census API |
| `R/05_territory_coverage.R` | Matches target operating subsidiaries to HIFLD service territory polygons; produces coverage gap report |
| `R/06_utility_tract_crosswalk.R` | Assigns census tracts to operating subsidiaries via centroid-in-polygon; produces the utility-tract crosswalk |
| `R/07_burden_estimates_2024.R` | Joins DOE LEAD 2022 baseline to the crosswalk, applies income/electricity/gas growth ratios, computes 2024 per-row burden |
| `R/08_burden_summary.R` | Aggregates 2024 burden estimates to per-utility weighted mean, weighted median, and share above 6% |
| `R/09_final_summary.R` | Joins the four pipeline outputs with EIA 861 electric customer counts and PUDL EIA 176 gas customer counts; computes CEO pay rank against the full EPI universe and percent-change versions of the profit ratios; writes the convening's primary CSV and formatted Excel deliverable |
