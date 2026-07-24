# 03_clean_full_report.R
# Clean the whole by-town report, not just Hartford, so any town's
# numbers can be pulled on demand without redoing the work.

library(dplyr)
library(readr)
library(here)
library(janitor)
library(tidyr)
library(stringr)
library(lubridate)
library(glue)

covid_data <- read_csv(here("data", "raw", "ct_covid_by_town_2026-06-30.csv"))

# --- the cleaning pass -------------------------------------------------

covid_clean <-
  covid_data |>
  clean_names() |>
  mutate(
    last_update_date = mdy(last_update_date),
    town = town |> str_trim() |> str_to_title()
  ) |>
  # group_by(town) first, or lag() subtracts the last row of one town
  # from the first row of the next
  arrange(town, last_update_date) |>
  group_by(town) |>
  mutate(new_cases = total_cases - lag(total_cases)) |>
  ungroup()

# --- this week's snapshot ----------------------------------------------

latest_date <- max(covid_clean$last_update_date)

this_week <-
  covid_clean |>
  filter(last_update_date == latest_date)

# one ready-made sentence per town
town_lines <-
  this_week |>
  mutate(
    line = glue(
      "{town}: {total_cases} total cases ({new_cases} new), {total_deaths} deaths"
    )
  ) |>
  select(town, line)

town_lines |>
  filter(town %in% c("Hartford", "New Haven", "Bridgeport")) |>
  pull(line)

# --- weekly trend appendix for the largest cities ----------------------

cities_of_interest <- c(
  "Hartford",
  "New Haven",
  "Bridgeport",
  "Stamford",
  "Waterbury"
)

weekly_trend <-
  covid_clean |>
  filter(town %in% cities_of_interest) |>
  mutate(week = floor_date(last_update_date, "week")) |>
  group_by(town, week) |>
  summarise(avg_new_cases = mean(new_cases, na.rm = TRUE), .groups = "drop")

weekly_trend |>
  pivot_wider(
    names_from = week,
    values_from = avg_new_cases,
    names_prefix = "week_of_"
  ) |>
  clean_names()

# --- save the artifact -------------------------------------------------
# Every later script starts from this file instead of re-deriving it.

write_csv(covid_clean, here("data", "processed", "covid_clean.csv"))
