# Line-list practice module

A **self-contained practice track**, separate from the Commissioner-briefing
project in `after-ch-00` … `after-ch-04`. Those snapshots are the real
deliverable, built on real town-level counts. This one is a sandbox for
practicing **case-level** work on a **synthetic** dataset.

> [!WARNING]
> `data/synthetic-covid-linelist.csv` is **fake**. The town names and case
> counts come from the real CT Open Data Portal, but every age, sex,
> race/ethnicity, date, and outcome is randomly generated. No row is a real
> person. Never analyze it as real data or fold it into real reporting.

## Scripts (run in order)

1. **`01_make_synthetic_linelist.R`** — expands the real Hartford County counts
   you downloaded in Chapter 1 into one row per case, then attaches simulated
   demographics and outcomes. Writes `data/synthetic-covid-linelist.csv`.
   *Chapter: Building a Dataset.*
2. **`02_describe_and_test.R`** — descriptives (`tabyl`), a cross-tab with row
   percents, chi-square, Fisher's exact, and a trend-in-proportions test.
   *Chapter: Describing and Testing.*
3. **`03_model_deaths.R`** — a logistic regression with `broom` for adjusted
   odds ratios. *Chapter: Modeling.*

## What you need first

- The real town CSV in `data/raw/` from Chapter 1
  (`ct_covid_by_town_2026-06-30.csv`) — `01` reads it.
- Packages: `readr`, `dplyr`, `tidyr`, `janitor`, `stringr`, `lubridate`,
  `here` (all from earlier chapters), plus `broom` for the model in `03`.

Run `01` once to build the line-list, then `02` and `03` read it. Because the
generator is seeded, re-running `01` reproduces the same file every time.
