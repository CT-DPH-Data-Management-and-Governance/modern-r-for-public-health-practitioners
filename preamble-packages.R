#' Documentation site for each package used across the book.
#'
#' Add an entry here the first time a package is introduced. Chapters
#' reference packages by name only (in their YAML `packages:` field);
#' this table is the single place the URL lives.
package_doc_urls <- list(
  dplyr = "https://dplyr.tidyverse.org/",
  readr = "https://readr.tidyverse.org/",
  fs = "https://fs.r-lib.org/",
  here = "https://here.r-lib.org/",
  ggplot2 = "https://ggplot2.tidyverse.org/",
  sf = "https://r-spatial.github.io/sf/",
  tigris = "https://github.com/walkerke/tigris",
  leaflet = "https://rstudio.github.io/leaflet/",
  mapview = "https://r-spatial.github.io/mapview/",
  httr2 = "https://httr2.r-lib.org/",
  janitor = "https://sfirke.github.io/janitor/",
  tidyr = "https://tidyr.tidyverse.org/",
  stringr = "https://stringr.tidyverse.org/",
  lubridate = "https://lubridate.tidyverse.org/"
)

#' Render a "packages covered" callout from a chapter's YAML `packages:` field.
#'
#' Call with `results: asis` and `echo: false` so the markdown it emits
#' is rendered rather than shown as code output.
#'
#' @param pkgs Character vector of package names, e.g. from
#'   `rmarkdown::metadata$packages`.
#' @param label Text describing the scope of the callout, e.g. "this part".
packages_used_callout <- function(pkgs, label = "this part") {
  links <- vapply(
    pkgs,
    function(p) {
      url <- package_doc_urls[[p]]
      if (is.null(url)) {
        url <- paste0("https://cran.r-project.org/package=", p)
      }
      sprintf("[%s](%s)", p, url)
    },
    character(1)
  )

  cat(sprintf(
    '::: {.callout-note appearance="minimal"}\n**Packages covered in %s:** %s\n:::\n',
    label,
    paste(links, collapse = ", ")
  ))
}
