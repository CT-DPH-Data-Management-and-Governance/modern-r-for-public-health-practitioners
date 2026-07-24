# After Chapter 2 — Cleaning Data

Carries forward chapter 1's scripts and adds:

- `scripts/03_clean_full_report.R` — the full cleaning pass with `janitor`,
  `lubridate`, `stringr`, `tidyr`, and `glue`: clean every column name,
  parse the date, guard the town names, compute `new_cases` per town, and
  build a one-line summary and a weekly trend appendix.

This is the script that writes `data/processed/covid_clean.csv` — the
starting point for every chapter after this one.

`data/raw/` still holds only the downloaded CSV (not duplicated here);
`data/processed/` and `outputs/` stay empty until you run the scripts.
