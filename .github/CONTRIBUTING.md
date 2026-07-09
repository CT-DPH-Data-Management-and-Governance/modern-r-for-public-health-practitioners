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

### Package headers (`preamble-packages.R`)

Every chapter/project `.qmd` shows a "packages covered" callout at the top,
built from `preamble-packages.R`. Two pieces live there:

- `package_doc_urls` — lookup of package name → docs URL
- `packages_used_callout()` — renders the callout from a chapter's YAML `packages:` field

**Adding a package for the first time:** add one entry to `package_doc_urls`
in `preamble-packages.R`:

```r
package_doc_urls <- list(
  ...
  yourpkg = "https://yourpkg.docs.url/"
)
```

If you skip this, the callout still works — it falls back to
`https://cran.r-project.org/package=<name>` — but prefer linking the
package's own docs site when one exists.

**Setting up a new chapter or project `.qmd`:** put this at the top, right
after the YAML frontmatter, which must declare a `packages:` field listing
every package the chapter uses (the callout is generated from that field,
not from your code chunks):

```yaml
---
title: "Your Chapter Title"
packages: [pkg1, pkg2]
---
```

Then a setup chunk and the callout chunk:

```r
#| label: chapter-root
#| include: false
library(here)
source(here::here("preamble-packages.R"))
```

```r
#| label: packages-header
#| echo: false
#| results: asis
packages_used_callout(rmarkdown::metadata$packages)
```

- Chapters that build plots also `source(here::here("preamble-themes.R"))`
  in the same setup chunk (see `chapters/03-data-visualization/`)
- `packages_used_callout()` takes an optional `label` arg (default
  `"this part"`) if you want the callout text to read differently, e.g.
  `packages_used_callout(rmarkdown::metadata$packages, label = "this chapter")`

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
