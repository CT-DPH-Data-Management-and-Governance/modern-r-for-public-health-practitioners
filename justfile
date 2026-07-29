# Modern R for Public Health Practitioners — dev commands
# Run `just` or `just --list` to see all recipes.

set shell := ["bash", "-uc"]

yaml_files := "_quarto.yml .github/ISSUE_TEMPLATE/bug_report.yml .github/ISSUE_TEMPLATE/content_suggestion.yml .github/workflows/lint.yml .github/workflows/publish.yml"
# truthy check-keys is off because GitHub Actions requires a bare `on:` key,
# which yamllint otherwise reads as the boolean true.
yamllint_config := '{extends: default, rules: {line-length: disable, document-start: disable, truthy: {check-keys: false}}}'

# List available recipes
default:
    @just --list

# Full book render (all formats configured in _quarto.yml)
render:
    quarto render

# HTML-only render
render-html:
    quarto render --to html

# PDF-only render (requires TinyTeX: quarto install tinytex)
render-pdf:
    quarto render --to pdf

# Verify the Quarto installation/toolchain
quarto-check:
    quarto check

# Quick syntax/frontmatter check without executing code chunks
render-dry:
    quarto render --to html --no-execute

# --- Synthetic data ---------------------------------------------------------

# Rebuild the synthetic COVID-19 line-list (data/synthetic-covid-linelist.csv)
linelist-data:
    Rscript data-raw/make-synthetic-linelist.R

# Rebuild the synthetic lab-result feed. Default 25k rows -> data/.
# Usage: just lab-data            (the committed teaching file)
#        just lab-data 5000000    (a CSV big enough to hurt)
lab-data rows="25000" out="data/synthetic-covid-lab-results.csv":
    Rscript data-raw/make-synthetic-lab-results.R --rows {{rows}} --out {{out}}

# The same feed with every sender quirk turned on: per-lab datetime formats,
# town spelling drift, local (non-LOINC) test codes, result-text drift.
# Usage: just lab-data-messy
#        just lab-data-messy 25000 data/x.csv "--messy-parts dates,towns"
lab-data-messy rows="25000" out="data/synthetic-covid-lab-results-messy.csv" parts="--messy":
    Rscript data-raw/make-synthetic-lab-results.R --rows {{rows}} --out {{out}} {{parts}}

# Same feed written as a partitioned parquet dataset (needs the arrow package)
lab-data-parquet rows="5000000" out="data/scale/lab-results-parquet":
    Rscript data-raw/make-synthetic-lab-results.R --rows {{rows}} --out {{out}} --format parquet

# Format all R code (.R, .qmd) with air
fmt:
    air format .

# Check formatting without writing changes (CI-style)
fmt-check:
    air format --check .

# Lint repo YAML files (quarto config, issue templates, CI workflows)
yaml-lint:
    yamllint -d '{{yamllint_config}}' {{yaml_files}}

# Run every check: formatting, yaml, and a dry render
lint: fmt-check yaml-lint render-dry
    @echo "All checks passed."

# List active TODO markers left in chapter content
todos:
    grep -rn "TODO" chapters/ || echo "No TODOs found."

# --- Releases ---------------------------------------------------------------
# A release here means: a tagged commit on `main` whose rendered book is what
# GitHub Pages is serving. Tags are semver with a leading `v` (v0.1.0).

# Show the current version (latest tag) and commits since it
version:
    #!/usr/bin/env bash
    set -euo pipefail
    latest=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -z "$latest" ]; then
        echo "No tags yet. First release would be v0.1.0."
        echo "Commits so far: $(git rev-list --count HEAD)"
    else
        echo "Current version: $latest"
        echo "Commits since:"
        git log --oneline "$latest"..HEAD
    fi

# Everything that must pass before a release is cut
release-check: lint todos
    #!/usr/bin/env bash
    set -euo pipefail
    echo "--> Checking working tree is clean"
    if [ -n "$(git status --porcelain)" ]; then
        echo "ERROR: uncommitted changes. Commit or stash first." >&2
        git status --short >&2
        exit 1
    fi
    echo "--> Checking you are on main"
    branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$branch" != "main" ]; then
        echo "ERROR: on '$branch', not 'main'." >&2
        exit 1
    fi
    echo "--> Full render (this is what CI will publish)"
    quarto render
    echo "Release checks passed."

# Draft release notes from commits since the last tag
release-notes:
    #!/usr/bin/env bash
    set -euo pipefail
    latest=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -z "$latest" ]; then
        git log --pretty=format:'- %s'
    else
        git log --pretty=format:'- %s' "$latest"..HEAD
    fi

# Cut a release: verify, tag, push, and open a GitHub release
# Usage: just release v0.2.0
release version:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! "{{version}}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: version must look like v1.2.3, got '{{version}}'." >&2
        exit 1
    fi
    if git rev-parse "{{version}}" >/dev/null 2>&1; then
        echo "ERROR: tag {{version}} already exists." >&2
        exit 1
    fi
    just release-check
    echo "--> Tagging {{version}}"
    git tag -a "{{version}}" -m "Release {{version}}"
    echo "--> Pushing tag"
    git push origin "{{version}}"
    echo "--> Creating GitHub release"
    just release-notes > /tmp/release-notes-{{version}}.md
    gh release create "{{version}}" \
        --title "{{version}}" \
        --notes-file /tmp/release-notes-{{version}}.md
    echo "Released {{version}}. Pages publishes from the push to main."

# Remove rendered output and frozen execution cache (forces full re-render)
clean:
    rm -rf _book _freeze
