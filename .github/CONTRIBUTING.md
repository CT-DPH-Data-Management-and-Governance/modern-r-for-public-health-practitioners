# Contributing

Thanks for helping make this book better. Contributions welcome from all skill levels — you don't need to be an R expert.

## What to contribute

- **Typo / grammar fixes** — open a PR directly
- **Broken code** — open a Bug Report issue
- **Unclear explanations** — open a Content Suggestion issue
- **New exercises or examples** — open a Content Suggestion issue first, discuss before writing

## Setup

1. Fork and clone the repo
2. Install [Quarto](https://quarto.org/docs/get-started/) — optional, but highly recommended so you can render and preview locally. `.github/workflows/publish.yml` renders and publishes the live site automatically on push to `main`, so Quarto isn't required just to open a PR, only to check your work before submitting one.
3. Open R and run `renv::restore()` to install packages
4. (Optional) Install [just](https://github.com/casey/just) and [air](https://posit-dev.github.io/air/) — the repo ships a `justfile` with render/format/lint recipes, see below
5. Render to verify your setup:

```bash
quarto render
```

Output lands in `_book/` (gitignored, local preview only). If render succeeds, you're good.

## Making changes

- Book source lives in `chapters/` — one folder per chapter, `index.qmd` is the main file
- `_quarto.yml` controls chapter order and book config
- `preamble.Rmd` holds shared R setup (color palettes, ggplot themes, scaffold function)
- After editing, render and check `_book/` output before submitting

### Using the justfile

Run `just --list` for the full set of recipes. Before opening a PR:

```bash
just fmt        # format R code with air
just lint        # fmt-check + yaml-lint + a no-execute render check
```

`just fmt` runs `air format .`; if you don't have `just` installed, `air format .` and `quarto render` directly work the same.

### CI

`.github/workflows/lint.yml` runs `just fmt-check`, `just yaml-lint`, and `just render-dry` on every push/PR to `dev` and `main`. These are informational only — every step is `continue-on-error`, so nothing here blocks a merge. A flagged step just means something's worth a look before or after merging.

`.github/workflows/publish.yml` is separate — it renders the book and publishes it to `gh-pages` on push to `main`. That's the one that actually ships the live site; you don't run it yourself.

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
- Format R code with `air format .` (or `just fmt`) before submitting

## Pull requests

- One logical change per PR
- Reference the issue number if one exists (`Closes #123`)
- Fill out the PR template

## Questions

Open a Discussion or an issue — no question is too small.
