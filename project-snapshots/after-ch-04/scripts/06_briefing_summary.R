# 06_briefing_summary.R
# The checkpoint artifact: a short status paragraph the Commissioner can
# read before the meeting starts. No new packages - just dplyr, lubridate
# and glue doing what they already do.

library(dplyr)
library(readr)
library(here)
library(lubridate)
library(glue)

covid_clean <- read_csv(here("data", "processed", "covid_clean.csv"))

latest_date <- max(covid_clean$last_update_date)
days_of_data <- as.numeric(latest_date - min(covid_clean$last_update_date))

statewide_latest <-
  covid_clean |>
  filter(last_update_date == latest_date) |>
  summarise(
    total_cases = sum(total_cases, na.rm = TRUE),
    total_deaths = sum(total_deaths, na.rm = TRUE)
  )

hartford_latest <-
  covid_clean |>
  filter(town == "Hartford", last_update_date == latest_date) |>
  select(total_cases, total_deaths)

briefing_summary <- glue(
  "Status as of {latest_date} ({days_of_data} days of data collected):\n",
  "Statewide: {format(statewide_latest$total_cases, big.mark = ',')} total cases, ",
  "{format(statewide_latest$total_deaths, big.mark = ',')} total deaths.\n",
  "Hartford: {format(hartford_latest$total_cases, big.mark = ',')} total cases, ",
  "{format(hartford_latest$total_deaths, big.mark = ',')} total deaths."
)

briefing_summary

write_lines(
  briefing_summary,
  here("outputs", "tables", "briefing_summary.txt")
)
