# United Ratepayers Strategy Convening 2026

A project in partnership with [People's Action Institute](https://peoplesaction.org/) for the **2026 United Ratepayers Strategy Convening**, producing a comparative analysis of ten investor-owned utilities (IOUs) across utility profits, CEO compensation, energy burdens, and (where available) shutoffs for non-payment.

## Goal

Compare ten major IOUs across four dimensions — annual profits and profit growth, CEO total compensation, residential energy costs and energy burdens, and (where data permits) shutoffs for non-payment — and assemble findings into a single summary CSV for use at the convening.

## Target Utilities

| # | Utility | Entity Type | Notes |
|---|---------|------------|-------|
| 1 | American Electric Power (AEP) | Holding co. | Multi-state IOU parent |
| 2 | ComEd | Operating subsidiary of Exelon | Profits/CEO at Exelon level; energy burden/shutoffs at ComEd level |
| 3 | Duke Energy | Holding co. | Multi-state IOU parent |
| 4 | Exelon | Holding co. | Parent of ComEd, PECO, BGE, etc. (overlap with row 2 noted) |
| 5 | National Grid | Holding co. (US subs) | NY, MA |
| 6 | PG&E | Holding + operating | California |
| 7 | Xcel Energy | Holding co. | Parent of PSCo (CO), NSP-MN, SPS (TX/NM) |
| 8 | Arizona Public Service Company (APS) | Operating sub. of Pinnacle West | Profits/CEO likely at Pinnacle West level |
| 9 | El Paso Electric | Stand-alone IOU | TX/NM (privately held since 2020 IIF acquisition — financial disclosure caveat) |
| 10 | Southern Company | Holding co. | Parent of Georgia Power, Alabama Power, Mississippi Power |

## Final Deliverable

The primary output is a summary CSV with one row per utility:

| Column | Description |
|--------|-------------|
| `utility_name` | Operating or holding-co. name |
| `ceo_name` | CEO as of most recent proxy |
| `ceo_pay` | Total compensation, most recent year (USD) |
| `ceo_pay_rank` | Rank 1–10 (1 = highest) |
| `most_recent_profits` | Net income, most recent FY (USD) |
| `profit_growth_2024_2025` | (NI_2025 − NI_2024) / NI_2024 |
| `profit_growth_2021_2025` | (NI_2025 − NI_2021) / NI_2021 |
| `avg_energy_cost` | Mean residential annual energy cost in service territory (USD) |
| `avg_energy_burden` | Mean residential energy burden (% of income) |
| `pct_unaffordable_burden` | Share of customers above the affordability threshold |

## How to Run

See `CLAUDE.md` for current status.

## Outputs

- Summary CSV — primary deliverable: one row per utility with all comparative metrics
- Supporting visualizations, if any

## Data Sources

### CEO Compensation
**Source:** Energy and Policy Institute (EPI) — [*Utility Executive Compensation 2025*](https://energyandpolicy.org/executive-compensation/)  
**Coverage:** 8 of 10 target utilities have data.

| Utility | Data Available | Notes |
|---------|---------------|-------|
| American Electric Power (AEP) | Yes | Direct match |
| ComEd | Yes | Matched at Exelon holding-company level |
| Duke Energy | Yes | CEO transition in 2025; Harry Sideris (incumbent) used |
| Exelon | Yes | Direct match |
| National Grid | **No** | UK-based parent; US subsidiaries not in EPI dataset |
| PG&E | Yes | Direct match (`PG&E Corporation`) |
| Xcel Energy | Yes | Direct match |
| Arizona Public Service (APS) | Yes | Matched at Pinnacle West holding-company level; CEO transition in 2025, Theodore Geisler (incumbent) used |
| El Paso Electric | **No** | Privately held since 2020 (IIF acquisition); not in EPI dataset |
| Southern Company | Yes | Direct match |

### Utility Profits
**Source:** Energy and Policy Institute (EPI) — [*Utility Profit Report*](https://energyandpolicy.org/utility-profit-report/)  
**Coverage:** 9 of 10 target utilities present in EPI data; 8 of 10 have complete 2021/2024/2025 profit figures. El Paso Electric has no row (privately held since 2020). National Grid 2025 profit data is not available in EPI source (2021 and 2024 are present).

| Utility | Match column | Subsidiaries summed | Notes |
|---------|-------------|---------------------|-------|
| American Electric Power | Parent Company | AEP Indiana/Michigan; AEP Texas; Appalachian Power; Kentucky Power; Ohio Power Co.; Public Service Co. of OK; SWEPCO | 7 subs |
| ComEd | Utility | ComEd | Operating-utility row; distinct from Exelon total |
| Duke Energy | Utility (substring) | Duke Energy Carolinas; Duke Energy Florida; Duke Energy Indiana; Duke Energy Ohio/Kentucky; Duke Energy Progress | Special case — Parent Company inconsistent in EPI source |
| Exelon | Parent Company | Atlantic City; BGE; ComEd; Delmarva; PECO; Potomac Electric Power (PEPCO) | 6 subs (ComEd overlaps with ComEd target by design) |
| National Grid | Parent Company | Massachusetts Electric Co.; Nantucket Electric; Niagara Mohawk | **2025 profit data not available in EPI source** — 2021 ($438.6M) and 2024 ($443.6M) present |
| PG&E | Parent Company | Pacific Gas & Electric Co. | 2021 profit ($138M) low due to post-bankruptcy recovery; 2021→2025 ratio (~22×) is technically correct but context-dependent |
| Xcel Energy | Utility (substring) | Xcel (electric subsidiaries) | EPI reports Xcel subs as single aggregated row |
| Arizona Public Service (APS) | Utility | Arizona Public Service Co. (APS) | Operating-utility row; distinct from Pinnacle West total |
| El Paso Electric | — | **No match** | Not in EPI dataset — privately held since 2020 (IIF acquisition) |
| Southern Company | Parent Company | Alabama Power; Georgia Power; Mississippi Power | 3 subs |

### Tract-Level Median Household Income
**Source:** U.S. Census Bureau — American Community Survey (ACS) 5-year estimates, via the Census API  
**Variable:** `B19013_001` — Median Household Income in the Past 12 Months (in inflation-adjusted dollars)  
**Geographic resolution:** Census tract  
**Temporal resolution:** 2022 ACS 5-year (2018–2022 reference period) and 2024 ACS 5-year (2020–2024 reference period)  
**Coverage:** 34 states + DC — all jurisdictions where target IOU service territories are expected to operate, derived from the HIFLD territory coverage audit  
**Output:** `Data/us_census/acs/{year}/tract/B19013_{state}.csv` — one file per state per year (68 files total); tidy format with columns `GEOID`, `NAME`, `variable`, `estimate`, `moe`

### Shutoffs for Non-Payment (Disconnections)
**Source:** Energy Justice Lab — [*Utility Disconnection Dashboard*](https://utilitydisconnections.org/)  
**Coverage:** 44 states + D.C.; monthly granularity 1996–2025.

EJL disconnection data covers shutoffs for non-payment specifically.

**Year selection:** For each matched operating utility / state / service-type combination, the script uses the most recent calendar year for which all 12 months are reported. Where no such year exists, the combination is excluded and logged as a gap.

**Double-counting prevention:** EJL contains both separate Electric and Gas rows AND a combined "Electric and Gas Customers" row for PECO (Exelon) and Xcel Energy (CO). The combined rows are excluded globally before matching to prevent double-counting. Separate Electric and Gas totals are reported instead.

| Utility | EJL Match | Subsidiaries / States | Gaps |
|---------|-----------|----------------------|------|
| American Electric Power | Substring: `AEP`, `Appalachian Power`, `Indiana Michigan`, `Kentucky Power`, `Ohio Power` | AEP Texas (TX), Appalachian Power (VA), Indiana Michigan Power (IN/MI), Kentucky Power (KY), Ohio Power (OH) | SWEPCO and PSO absent from EJL |
| ComEd | Exact: `Commonwealth Edison` | Commonwealth Edison (IL) | — |
| Duke Energy | Substring: `Duke Energy` | Carolinas (NC/SC), Florida (FL), Indiana (IN), Kentucky (KY), Ohio (OH), Progress (NC/SC) | — |
| Exelon | Exact: BGE, Delmarva Power, PECO Electric, PECO Gas | Baltimore Gas and Electric (MD), Delmarva Power (MD), PECO (PA) | Pepco and Atlantic City Electric absent from EJL |
| National Grid | Exact: MA Electric, Nantucket, Niagara Mohawk, KeySpan KEDLI/KEDNY, Brooklyn Union Gas | Across MA and NY | — |
| PG&E | Exact: `Pacific Gas & Electric Co` | Pacific Gas & Electric (CA) | — |
| Xcel Energy | Substring: `Xcel Energy`, `Northern States Power`, `Southwestern Public Service` | Xcel Energy (MN/CO), NSP (WI/MI/ND/SD), SPS (NM) | — |
| Arizona Public Service (APS) | Exact: `Arizona Public Service Company` | Arizona Public Service (AZ) | — |
| El Paso Electric | Substring: `El Paso Electric` | El Paso Electric Company (NM) | TX data absent from EJL |
| Southern Company | Exact: `Georgia Power`, `Alabama Power`, `Mississippi Power` | Georgia Power (GA) | Alabama Power and Mississippi Power absent from EJL |

### Electric Retail Service Territories (GIS)
**Source:** Oak Ridge National Laboratory (ORNL) / U.S. Department of Energy (DOE), via HIFLD Open  
**URL:** https://hifld-geoplatform.hub.arcgis.com/ (archived — repository deactivated August 26, 2025)  
**Format:** ESRI Shapefile, 2,931 features, CRS: WGS 1984 Web Mercator Auxiliary Sphere (EPSG:3857)  
**Local path:** `Data/gis/hflid_ornl/electric-retail-service-territories/`  
**Script:** `R/05_territory_coverage.R`  
**Output:** `outputs/<date>-territory-coverage-gap-report.md`

Electric power retail service territory polygons representing areas serviced by electric utilities responsible for the retail sale of electric power to local customers. Used to spatially define service territories for energy burden calculations.

**Coverage audit results** (run 2026-05-24): All 34 expected operating subsidiaries across the 10 target holding companies matched at least one territory polygon. No gaps.

| Holding Co | Subsidiaries matched | Customers in shapefile |
|---|---|---|
| Duke Energy | 6/6 | 8,204,861 |
| PG&E | 1/1 | 5,604,453 |
| Exelon (excl. ComEd) | 5/5 | 5,060,114 |
| ComEd | 1/1 | 4,111,175 |
| Southern Company | 3/3 | 4,431,047 |
| American Electric Power | 8/8 | 4,418,432 |
| Xcel Energy | 4/4 | 3,761,046 |
| National Grid | 4/4 | 3,579,978 |
| Arizona Public Service | 1/1 | 1,344,359 |
| El Paso Electric | 1/1 | 455,303 |

Known caveats from the audit:
- **AEP Texas customer count**: Both AEP Texas features have no customer count in the shapefile; will be sourced from EIA 861.
- **`STATE` field unreliable**: For AEP subsidiaries and both Northern States Power entries, `STATE` reflects the holding company's HQ state, not the service territory state. Use polygon geometry for state assignment in downstream analysis.
- **Narragansett Electric (RI)**: National Grid sold Narragansett Electric to PPL in 2022; the shapefile (vintage Aug 2023) still lists National Grid as owner. Territory is attributed to National Grid with this caveat noted.

### Census Tract Boundaries (2022 Cartographic Boundary)
**Source:** U.S. Census Bureau — Cartographic Boundary Files, 1:500,000 resolution  
**URL:** https://www.census.gov/geographies/mapping-files/time-series/geo/carto-boundary-file.html  
**Format:** ESRI Shapefile, nationwide  
**Local path:** `Data/gis/census/cb_2022_us_tract_500k/`  
**Script:** `R/06_utility_tract_crosswalk.R`

Census tract boundary polygons used for centroid-in-polygon assignment of tracts to utility service territories. Each tract's geographic centroid is tested for containment within each operating subsidiary's HIFLD territory polygon.

### DOE LEAD 2022 — Tract-Level Energy Burden Baseline
**Source:** U.S. Department of Energy — Low-Income Energy Affordability Data (LEAD) Tool  
**URL:** https://www.energy.gov/scep/slsc/low-income-energy-affordability-data-lead-tool  
**Variables:** `avg_income`, `avg_electricity_cost`, `avg_gas_cost`, `avg_other_fuel_cost`, plus `hincp_valid_units`, `elep_valid_units`, `gasp_valid_units`, `fulp_valid_units` (per-component household counts used as weights)  
**Geographic resolution:** Census tract × subpopulation (income band × tenure × building age × heating fuel)  
**Temporal resolution:** 2022 (5-year ACS reference period)  
**Coverage:** 34 target states  
**Local path:** `Cleaned_Data/doe/lead/[state]-census_tract-lead-2022.csv` (one file per state)  
**Script:** `R/07_burden_estimates_2024.R`

Tract-level baseline energy burden data used as the 2022 starting point for forward-projection to 2024. Multiple subpopulation rows per tract are preserved to enable accurate weighted aggregation.

### Residential Electricity Sales (EIA Form 861)
**Source:** U.S. Energy Information Administration — Form EIA-861 (Annual Electric Power Industry Report)  
**URL:** https://www.eia.gov/electricity/data/eia861/  
**Variables:** `residential_revenue_usd`, `residential_customers` (combined to compute average annual residential bill = revenue ÷ customers)  
**Geographic resolution:** Operating utility × state  
**Temporal resolution:** Annual; 2022 and 2024 used  
**Coverage:** 47 of 48 expected operating subsidiary × state combinations matched  
**Local path:** `Cleaned_Data/eia/861/14-02-2026-eia-861-sales.csv`  
**Script:** `R/07_burden_estimates_2024.R`

Used to compute the 2022→2024 electricity-bill growth ratio per operating subsidiary × state. This ratio is applied multiplicatively to the DOE LEAD 2022 electricity cost baseline to project forward to 2024.

### Residential Natural Gas Bills (EIA Form 176)
**Source:** U.S. Energy Information Administration — Form EIA-176 (Annual Report of Natural and Supplemental Gas Supply and Disposition)  
**URL:** https://www.eia.gov/naturalgas/ngqs/  
**Variable:** `avg_annual_residential_nat_gas_bill`  
**Geographic resolution:** State (no utility-level breakdown available)  
**Temporal resolution:** Annual; 2022 and 2024 used  
**Coverage:** 50 states + DC  
**Local path:** `Cleaned_Data/eia/176/15-04-2026-eia-176-residential-natural-gas.csv`  
**Script:** `R/07_burden_estimates_2024.R`

Used to compute the 2022→2024 gas-bill growth ratio per state. Applied multiplicatively to the DOE LEAD 2022 gas cost baseline. Because EIA 176 has no utility-level breakdown, all tracts within a given state use the same gas growth ratio regardless of which utility serves them.

## Notes & Caveats

- **ComEd/Exelon overlap**: ComEd (row 2) is an operating subsidiary of Exelon (row 4). Financial metrics (net income, CEO pay) are reported at the Exelon holding-company level; energy burden and shutoff data are at the ComEd operating level. Both rows are retained to reflect the analysis scope.
- **El Paso Electric**: Privately held since 2020 (acquired by IIF). Public financial disclosures are limited; profit and executive compensation data may be unavailable or incomplete.
- **APS/Pinnacle West**: Arizona Public Service Company is an operating subsidiary of Pinnacle West Capital. Financial metrics are reported at the Pinnacle West level.
- **Xcel Energy**: Xcel is the parent holding company of PSCo (Colorado), NSP-MN (Minnesota/North Dakota/South Dakota), and SPS (Texas/New Mexico). Energy burden analysis may reference operating subsidiaries rather than the consolidated parent.
- **Profits — Duke Energy aggregation**: Duke Energy's `Parent Company` column is inconsistent in the EPI source (only "Duke Energy Florida" carries it). Profits are aggregated by matching `Utility` column substring `"Duke Energy"` across all Duke subs.
- **Profits — ComEd vs. Exelon**: The profits script uses ComEd's own operating-utility row (not Exelon's parent total) for the ComEd target, while the exec-comp script uses Exelon's holding-company row for both. This divergence is intentional and reflects different reporting levels.
- **Profits — APS vs. Pinnacle West**: Same logic as ComEd/Exelon — the profits script uses APS's operating-utility row; the exec-comp script uses Pinnacle West's holding-company row.
- **Profits — Xcel aggregation**: `Xcel Energy` does not appear as a value in the `Parent Company` column of the EPI profits data. Subsidiaries are matched by `Utility`-name substring across Northern States Power, Public Service Co. of Colorado, Southwestern Public Service, and any rows containing "Xcel".
- **Profits — National Grid 2025 gap**: EPI does not report 2025 profit data for National Grid's US subsidiaries. 2021 ($438.6M) and 2024 ($443.6M) figures are available; `profit_2025_millions` and `profit_ratio_2024_2025` are NA for this utility.
- **Profits — El Paso Electric gap**: El Paso Electric is not present in EPI's utility profits data. It has been privately held since 2020 (IIF acquisition) and does not file public financial disclosures.
