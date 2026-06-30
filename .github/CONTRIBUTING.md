# Contributing

Thanks for helping make this book better. Contributions welcome from all skill levels — you don't need to be an R expert.

## What to contribute

- **Typo / grammar fixes** — open a PR directly
- **Broken code** — open a Bug Report issue
- **Unclear explanations** — open a Content Suggestion issue
- **New exercises or examples** — open a Content Suggestion issue first, discuss before writing

## Setup

1. Fork and clone the repo
2. Install [Quarto](https://quarto.org/docs/get-started/)
3. Open R and run `renv::restore()` to install packages
4. Render to verify your setup:

```bash
quarto render
```

Output lands in `docs/`. If render succeeds, you're good.

## Making changes

- Book source lives in `chapters/` — one folder per chapter, `index.qmd` is the main file
- `_quarto.yml` controls chapter order and book config
- `preamble.Rmd` holds shared R setup (color palettes, ggplot themes, scaffold function)
- After editing, render and check `docs/` output before submitting

## Code style

- Tidyverse only — no base R in chapter code (see `CLAUDE.md` for rationale)
- Packages: `readr`, `dplyr`, `fs`, `readxl`, `writexl` — stick to what chapters already use unless there's a strong reason
- Keep examples grounded in the CT COVID-19 dataset (`ct-covid-by-town-2026-06-30.csv`)

## Pull requests

- One logical change per PR
- Reference the issue number if one exists (`Closes #123`)
- Fill out the PR template

## Questions

Open a Discussion or an issue — no question is too small.
