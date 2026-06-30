# Modern R for Public Health Practitioners

A project-based course for public health practitioners (epidemiologists, SAS users) who want to become confident R users by building a COVID-19 CT data report that grows with every chapter.

Hosted: <https://ct-dph-data-management-and-governance.github.io/modern-r-for-public-health-practitioners/>

## Structure

| Chapter | Topic |
|---|---|
| 00 — Orientation | Mindset, RStudio/Positron setup, folder structure, data download |
| 01 — Working with Real Data | `readr`, `dplyr`, `fs`; load and inspect the CT COVID-19 dataset |
| APIs & Functions | Pulling data from SODA/open data APIs |
| Security Basics | Managing secrets and credentials |
| Further Reading | Excel files, writing files |

Readers **code along in their own local project** (`covid-briefing/`) — no cloning required.

## Development Setup

### Prerequisites

- [R](https://cran.r-project.org/)
- [Quarto](https://quarto.org/docs/get-started/)

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
quarto render              # full book → docs/
quarto render --to html    # HTML only
quarto render --to pdf     # PDF only
```

Output lands in `docs/`. The repo uses `execute: freeze: auto` — code chunks only re-run when source changes. To force re-execution, delete the relevant entry in `_freeze/` or pass `--execute`.
