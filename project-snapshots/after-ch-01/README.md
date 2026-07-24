# After Chapter 1 — Working with Real Data

Adds:

- `scripts/01_load_and_inspect.R` — load the raw CSV with `readr`/`here`,
  `head()`/`glimpse()` it.
- `scripts/02_hartford_first_look.R` — filter to Hartford, clean up column
  names, parse the date, sort, compute daily `new_cases` from the cumulative
  total, and answer "is it getting worse in Hartford?"

`data/raw/` still holds only the downloaded CSV (not duplicated here);
`data/processed/` and `outputs/` stay empty until the reader runs the scripts.
