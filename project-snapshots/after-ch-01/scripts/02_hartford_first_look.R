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
    new_positives = `Number of positives`,
    total_cases = `Total cases`,
    total_deaths = `Total deaths`
  ) |>
  mutate(date = parse_date(date, format = "%m/%d/%Y")) |>
  arrange(date)

tail(hartford, 14)

# Saving our data artifact
# write_csv(hartford, here("data", "processed", "hartford.csv"))
