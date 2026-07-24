# 02_hartford_first_look.R
# Scope the loaded data down to Hartford and answer:
# is it getting worse in Hartford?

library(dplyr)
library(readr)
library(here)

covid_data <- read_csv(here("data", "raw", "ct_covid_by_town_2026-06-30.csv"))

hartford <-
  covid_data |>
  filter(Town == "Hartford") |>
  select(
    date = `Last update date`,
    town = Town,
    total_cases = `Total cases`,
    total_deaths = `Total deaths`
  ) |>
  mutate(date = parse_date(date, format = "%m/%d/%Y")) |>
  arrange(date) |>
  # total_cases is cumulative, so daily new cases is the change between one
  # report and the next. This can come out negative on a day the state
  # revises an earlier total - that's the data, not a bug.
  mutate(new_cases = total_cases - lag(total_cases))

tail(hartford, 14)

# Saving our data artifact
# write_csv(hartford, here("data", "processed", "hartford.csv"))
