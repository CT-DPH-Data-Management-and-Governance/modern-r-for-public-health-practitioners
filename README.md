# Modern R for Public Health Practitioners

A project-based course for public health practitioners (epidemiologists, SAS users) who want to become confident R users by building a COVID-19 CT data report that grows with every chapter.

Hosted: <https://ct-dph-data-management-and-governance.github.io/modern-r-for-public-health-practitioners/>

## Structure

| Chapter | Topic |
|---|---|
| 00 — Orientation | Mindset, RStudio/Positron setup, folder structure, data download |
| 01 — Working with Real Data | `readr`, `dplyr`, `fs`; load and inspect the CT COVID-19 dataset |
| Cleaning Data | `janitor`, `tidyr`, `stringr`, `lubridate`; tidy names, reshape, and parse dates |
| Data Visualization | `ggplot2`, `sf`, `tigris`, `leaflet`, `mapview`; static and interactive maps |
| Intermediate R: Automating the Manual Steps | `httr2`; pulling data from SODA/open data APIs and writing functions |
| Security Basics | Managing secrets and credentials |
| Further Reading | Joins, Excel files, writing files |

Readers **code along in their own local project** (`covid-briefing/`) — no cloning required.

## Development Setup

### Prerequisites

- [R](https://cran.r-project.org/)
- [Quarto](https://quarto.org/docs/get-started/) (optional, but highly recommended) — lets you render and preview locally before opening a PR. The live site is built and published automatically by `.github/workflows/publish.yml` on every push to `main`, so Quarto isn't strictly required to contribute, just to check your work first.
- [just](https://github.com/casey/just) (optional) — command runner for the recipes below
- [air](https://posit-dev.github.io/air/) (optional) — R formatter used by `just fmt`

### Restore R packages

```r
renv::restore()
```

### PDF rendering (TinyTeX)

```bash
quarto install tinytex
```

Installs TinyTeX into `~/.TinyTeX`. Missing LaTeX packages auto-install during render.

## Render

```bash
quarto render              # full book → _book/
quarto render --to html    # HTML only
quarto render --to pdf     # PDF only
```

Output lands in `_book/` (gitignored, local preview only). The repo uses `execute: freeze: auto` — code chunks only re-run when source changes. To force re-execution, delete the relevant entry in `_freeze/` or pass `--execute`.

## Publishing

`.github/workflows/publish.yml` renders the book with Quarto and publishes it to the `gh-pages` branch on every push to `main`. You don't need to run this yourself — it's how the [hosted site](https://ct-dph-data-management-and-governance.github.io/modern-r-for-public-health-practitioners/) stays in sync with `main`.

## Common commands (`just`)

A `justfile` wraps the commands above plus formatting and linting. Run `just --list` to see everything.

```bash
just render       # quarto render
just render-html  # quarto render --to html
just render-dry   # quick syntax/frontmatter check, no code execution
just fmt           # format R code with air
just fmt-check      # check formatting without writing (CI-style)
just yaml-lint       # lint _quarto.yml and issue templates
just lint             # fmt-check + yaml-lint + render-dry, all at once
just todos             # list active TODO markers in chapters/
```

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for how to contribute, chapter conventions, and the package header setup.
