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

## Notes & Caveats

- **ComEd/Exelon overlap**: ComEd (row 2) is an operating subsidiary of Exelon (row 4). Financial metrics (net income, CEO pay) are reported at the Exelon holding-company level; energy burden and shutoff data are at the ComEd operating level. Both rows are retained to reflect the analysis scope.
- **El Paso Electric**: Privately held since 2020 (acquired by IIF). Public financial disclosures are limited; profit and executive compensation data may be unavailable or incomplete.
- **APS/Pinnacle West**: Arizona Public Service Company is an operating subsidiary of Pinnacle West Capital. Financial metrics are reported at the Pinnacle West level.
- **Xcel Energy**: Xcel is the parent holding company of PSCo (Colorado), NSP-MN (Minnesota/North Dakota/South Dakota), and SPS (Texas/New Mexico). Energy burden analysis may reference operating subsidiaries rather than the consolidated parent.
