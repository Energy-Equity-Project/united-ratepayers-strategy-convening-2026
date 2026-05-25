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

The primary output is `outputs/dd-mm-yyyy-united-ratepayers-utility-summary.csv` with one row per utility:

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

Analysis scripts will be added in `R/` (`01_*.R`, `02_*.R`, …). See `CLAUDE.md` for current status.

## Outputs

- `outputs/dd-mm-yyyy-united-ratepayers-utility-summary.csv` — primary deliverable: one row per utility with all comparative metrics
- `plots/` — supporting visualizations, if any

## Data Sources

### CEO Compensation
**Source:** Energy and Policy Institute (EPI) — [*Utility Executive Compensation 2025*](https://energyandpolicy.org/executive-compensation/)  
**File:** `../../Data/epi/EPI_Exec_Comp_Data_2025.csv`  
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
**File:** `../../Data/epi/2021 - 2025 Utility Profits (Make a copy to edit) _ Last Updated 5_8_26.xlsx` (sheet: `Data`)  
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

### Shutoffs for Non-Payment (Disconnections)
**Source:** Energy Justice Lab — [*Utility Disconnection Dashboard*](https://utilitydisconnections.org/)  
**File:** `../../Cleaned_Data/ejl_disconnection_dashboard/16-03-2026-ejl-disconnection-dashboard.csv`  
**Script:** `R/03_ejl_disconnections.R`  
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
