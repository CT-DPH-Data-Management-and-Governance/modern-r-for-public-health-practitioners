# modern-r-for-public-health-practitioners

A project-based course for public health practitioners who want to become confident R users by building a report that grows with every chapter.

## Usage

### Prerequisites

Install [Quarto](https://quarto.org/docs/get-started/) before proceeding.

### PDF rendering (TinyTeX)

Quarto renders this book to PDF via lualatex. Install TinyTeX through Quarto to get a user-owned TeX distribution that does not require root:

```bash
quarto install tinytex
```

This installs TinyTeX into `~/.TinyTeX`. Missing LaTeX packages are then auto-installed during render without needing system permissions.

### Render the book

```bash
quarto render
```

Output lands in `docs/`. To render only the PDF or only the HTML:

```bash
quarto render --to pdf
quarto render --to html
```
