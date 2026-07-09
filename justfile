# Modern R for Public Health Practitioners — dev commands
# Run `just` or `just --list` to see all recipes.

set shell := ["bash", "-uc"]

yaml_files := "_quarto.yml .github/ISSUE_TEMPLATE/bug_report.yml .github/ISSUE_TEMPLATE/content_suggestion.yml"
yamllint_config := '{extends: default, rules: {line-length: disable, document-start: disable}}'

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

# Format all R code (.R, .qmd) with air
fmt:
    air format .

# Check formatting without writing changes (CI-style)
fmt-check:
    air format --check .

# Lint repo YAML files (quarto config + issue templates)
yaml-lint:
    yamllint -d '{{yamllint_config}}' {{yaml_files}}

# Run every check: formatting, yaml, and a dry render
lint: fmt-check yaml-lint render-dry
    @echo "All checks passed."

# List active TODO markers left in chapter content
todos:
    grep -rn "TODO" chapters/ || echo "No TODOs found."

# Remove rendered output and frozen execution cache (forces full re-render)
clean:
    rm -rf docs _freeze
