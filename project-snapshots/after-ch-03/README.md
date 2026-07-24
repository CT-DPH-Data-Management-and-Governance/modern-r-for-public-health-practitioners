# After Chapter 3 — Data Visualization

Carries forward chapters 1–2 and adds:

- `scripts/04_hartford_trend_plot.R` — the Hartford new-case chart from the
  lesson, saved to `outputs/figures/hartford_new_cases.png`.
- `scripts/05_briefing_charts.R` — the briefing deck from the project:
  Hartford vs. the statewide average, a statewide test-positivity
  choropleth, and a top-5 / bottom-5 ranked list.

Both scripts read `data/processed/covid_clean.csv` rather than re-deriving
the cleaning pass — that was chapter 2's job.

**Note on themes.** These scripts use stock `ggplot2` themes and plain hex
codes, matching the chapters — nothing extra to install. The CT DPH brand
helpers are book styling only; see Further Reading if you have access to
them.

`data/raw/` still holds only the downloaded CSV (not duplicated here);
`data/processed/` and `outputs/` stay empty until you run the scripts.
