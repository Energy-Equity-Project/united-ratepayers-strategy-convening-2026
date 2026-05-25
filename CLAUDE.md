# United Ratepayers Strategy Convening 2026

## Purpose
Produce a comparative analysis of ten investor-owned utilities across profits, CEO compensation, energy burdens, and (where available) shutoffs for non-payment, delivering a single summary CSV for People's Action Institute's 2026 United Ratepayers Strategy Convening.

## Type
Research — this repo CONSUMES data from shared Data/ and Cleaned_Data/ folders.

## Status
active — repo setup phase; analysis pending

## Background
People's Action Institute is hosting the 2026 United Ratepayers Strategy Convening, bringing together ratepayer advocates from across the country. This project supports the convening by generating a comparative snapshot of ten major IOUs across four dimensions:

1. **Utility profits** — net income for FY2021, FY2024, and FY2025 (to compute growth rates)
2. **CEO compensation** — total compensation for the most recent proxy year
3. **Energy burdens** — average residential energy costs and energy burden (% of income) in each utility's service territory
4. **Shutoffs for non-payment** — disconnection counts, where reported (auxiliary output)

The deliverable is a single comparative CSV with one row per utility.

## Data Dependencies
*To be added in a follow-up task.*

## Analytical Approach
1. Compile annual net income (FY2021, FY2024, FY2025) for each holding company from SEC 10-K filings
2. Compile most-recent-year CEO total compensation for each holding company from SEC DEF 14A (proxy) filings
3. Compute service-territory-weighted average residential energy costs and energy burdens for each operating utility
4. Compute share of customers above the affordability threshold (unaffordable burden)
5. Assemble final summary CSV per schema in README.md
6. Auxiliary: compile shutoff/disconnection counts for each utility where publicly reported

## Key Files
- `R/01_financials.R` — compile net income and CEO pay from SEC filings (planned)
- `R/02_energy_burdens.R` — compute service-territory energy costs and burdens (planned)
- `R/03_assemble.R` — join all metrics into final summary CSV (planned)

## Outputs
- `outputs/dd-mm-yyyy-united-ratepayers-utility-summary.csv` — primary deliverable: one row per utility, all comparative metrics
- `outputs/dd-mm-yyyy-united-ratepayers-shutoffs.csv` — secondary output: disconnection data by utility (if data permits)

## External Partner
- **Partner**: People's Action Institute
- **Convening**: 2026 United Ratepayers Strategy Convening
- **Data restrictions**: None expected — analysis uses public data (SEC filings, EIA, DOE LEAD, ACS)
