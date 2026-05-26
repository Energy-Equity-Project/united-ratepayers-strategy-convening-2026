# Shared target-subsidiary table for United Ratepayers 2026 analysis.
# Sourced by 05_territory_coverage.R, 06_utility_tract_crosswalk.R, and
# 07_burden_estimates_2024.R to keep the 34-subsidiary list in one place.

library(tidyverse)

targets <- tribble(
  ~target_holding_co,           ~subsidiary_label,                  ~name_regex,                                          ~holding_co_regex,                  ~expected_states,
  # American Electric Power
  "American Electric Power",    "Appalachian Power",                "APPALACHIAN POWER",                                  "AMERICAN ELECTRIC POWER",          "VA,WV,TN",
  "American Electric Power",    "Indiana Michigan Power",           "INDIANA MICHIGAN POWER",                             "AMERICAN ELECTRIC POWER",          "IN,MI",
  "American Electric Power",    "Kentucky Power",                   "^KENTUCKY POWER",                                    "AMERICAN ELECTRIC POWER",          "KY",
  "American Electric Power",    "Ohio Power",                       "OHIO POWER",                                         "AMERICAN ELECTRIC POWER",          "OH",
  "American Electric Power",    "Public Service Co. of Oklahoma",   "PUBLIC SERVICE.*OKLAHOMA",                           "AMERICAN ELECTRIC POWER",          "OK",
  "American Electric Power",    "Southwestern Electric Power",      "SOUTHWESTERN ELECTRIC POWER|SWEPCO",                 "AMERICAN ELECTRIC POWER",          "AR,LA,TX",
  "American Electric Power",    "AEP Texas",                        "AEP TEXAS",                                          "AMERICAN ELECTRIC POWER",          "TX",
  "American Electric Power",    "Wheeling Power",                   "WHEELING POWER",                                     "AMERICAN ELECTRIC POWER",          "WV",
  # ComEd
  "ComEd",                      "Commonwealth Edison",              "COMMONWEALTH EDISON|COMED",                          "EXELON|COMMONWEALTH EDISON",       "IL",
  # Duke Energy
  "Duke Energy",                "Duke Energy Carolinas",            "DUKE ENERGY CAROLINAS",                              "DUKE ENERGY",                      "NC,SC",
  "Duke Energy",                "Duke Energy Progress",             "DUKE ENERGY PROGRESS|PROGRESS ENERGY CAROLINAS",     "DUKE ENERGY",                      "NC,SC",
  "Duke Energy",                "Duke Energy Florida",              "DUKE ENERGY FLORIDA|PROGRESS ENERGY FLORIDA",        "DUKE ENERGY",                      "FL",
  "Duke Energy",                "Duke Energy Indiana",              "DUKE ENERGY INDIANA",                                "DUKE ENERGY",                      "IN",
  "Duke Energy",                "Duke Energy Ohio",                 "DUKE ENERGY OHIO",                                   "DUKE ENERGY",                      "OH",
  "Duke Energy",                "Duke Energy Kentucky",             "DUKE ENERGY KENTUCKY",                               "DUKE ENERGY",                      "KY",
  # Exelon (includes ComEd subsidiaries so ComEd tracts roll up into Exelon)
  "Exelon",                     "Commonwealth Edison",              "COMMONWEALTH EDISON|COMED",                          "EXELON|COMMONWEALTH EDISON",       "IL",
  "Exelon",                     "Baltimore Gas & Electric (BGE)",   "BALTIMORE GAS|^BGE",                                 "EXELON",                           "MD",
  "Exelon",                     "PECO Energy",                      "PECO",                                               "EXELON",                           "PA",
  "Exelon",                     "Potomac Electric Power (Pepco)",   "POTOMAC ELECTRIC|PEPCO",                             "EXELON|PEPCO",                     "DC,MD",
  "Exelon",                     "Delmarva Power",                   "DELMARVA",                                           "EXELON|PEPCO",                     "DE,MD",
  "Exelon",                     "Atlantic City Electric",           "ATLANTIC CITY ELECTRIC",                             "EXELON|PEPCO",                     "NJ",
  # National Grid
  "National Grid",              "Niagara Mohawk",                   "NIAGARA MOHAWK",                                     "NATIONAL GRID",                    "NY",
  "National Grid",              "Massachusetts Electric",           "MASSACHUSETTS ELECTRIC",                             "NATIONAL GRID",                    "MA",
  "National Grid",              "Nantucket Electric",               "NANTUCKET ELECTRIC",                                 "NATIONAL GRID",                    "MA",
  "National Grid",              "Narragansett Electric",            "NARRAGANSETT ELECTRIC",                              "NATIONAL GRID",                    "RI",
  # PG&E
  "PG&E",                       "Pacific Gas & Electric",           "PACIFIC GAS",                                        "PG&E|PACIFIC GAS",                 "CA",
  # Xcel Energy
  "Xcel Energy",                "Northern States Power - MN",       "NORTHERN STATES POWER.*MINNESOTA",                   "XCEL ENERGY|NORTHERN STATES",      "MN,ND,SD",
  "Xcel Energy",                "Northern States Power - WI",       "^NORTHERN STATES POWER CO$",                         "XCEL ENERGY|NORTHERN STATES",      "WI,MI",
  "Xcel Energy",                "Public Service Co. of Colorado",   "PUBLIC SERVICE.*COLORADO",                           "XCEL ENERGY",                      "CO",
  "Xcel Energy",                "Southwestern Public Service",      "SOUTHWESTERN PUBLIC SERVICE",                        "XCEL ENERGY",                      "NM,TX",
  # Arizona Public Service
  "Arizona Public Service",     "Arizona Public Service",           "ARIZONA PUBLIC SERVICE",                             "PINNACLE WEST|ARIZONA PUBLIC SERVICE", "AZ",
  # El Paso Electric
  "El Paso Electric",           "El Paso Electric",                 "EL PASO ELECTRIC",                                   "EL PASO ELECTRIC",                 "TX,NM",
  # Southern Company
  "Southern Company",           "Alabama Power",                    "ALABAMA POWER",                                      "SOUTHERN CO|SOUTHERN COMPANY",     "AL",
  "Southern Company",           "Georgia Power",                    "GEORGIA POWER",                                      "SOUTHERN CO|SOUTHERN COMPANY",     "GA",
  "Southern Company",           "Mississippi Power",                "MISSISSIPPI POWER",                                  "SOUTHERN CO|SOUTHERN COMPANY",     "MS"
)
