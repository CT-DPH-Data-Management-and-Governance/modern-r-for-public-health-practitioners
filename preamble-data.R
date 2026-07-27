# Shared data access for chapters — sourced from preamble.Rmd
# Plain R file so chapters can `source()` this without Quarto chunk parsing issues.
#
# All chapters pull from a single top-level data/ folder instead of keeping
# their own copies. A chapter's hidden setup chunk never has to know its own
# position in the folder tree — it just asks for a file by name.

#' Path to a file in the book's shared data/ directory
#'
#' @param file File name inside `data/`, e.g. "ct-covid-by-town-2026-06-30.csv".
#'   Omit to get the directory itself.
#' @return Absolute path.
book_data_path <- function(file = NULL) {
  if (is.null(file)) {
    return(here::here("data"))
  }
  here::here("data", file)
}

#' Read a file straight out of the book's shared data/ directory
#'
#' Dispatches to readr or readxl based on file extension, so a chapter's
#' hidden setup chunk can pull in a dataset in one line without re-deriving
#' a path or picking a reader function.
#'
#' @param file File name inside `data/`.
#' @param ... Passed on to the underlying reader (`read_csv()`/`read_excel()`).
#' @return A tibble.
read_book_data <- function(file, ...) {
  path <- book_data_path(file)
  ext <- tolower(fs::path_ext(path))

  switch(
    ext,
    csv = readr::read_csv(path, ...),
    xlsx = ,
    xls = {
      rlang::check_installed("readxl", reason = "to read Excel files")
      readxl::read_excel(path, ...)
    },
    cli::cli_abort(
      "Don't know how to read {.file {file}} (extension {.val {ext}})."
    )
  )
}
