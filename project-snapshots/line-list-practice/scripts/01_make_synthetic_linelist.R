# ============================================================================
# 01_make_synthetic_linelist.R
#
# ***  SYNTHETIC DATA — NOT REAL.  DO NOT TREAT AS ACTUAL DPH RECORDS.  ***
#
# Builds a FAKE COVID-19 line-list (one row per case) from the REAL town-level
# counts you downloaded in Chapter 1. The counts control how many cases each
# town had; every demographic and outcome is randomly generated. No row is a
# real person. See the "Building a Dataset" chapter for the full walk-through.
#
# Reads : data/raw/ct_covid_by_town_2026-06-30.csv
# Writes: data/synthetic-covid-linelist.csv
# ============================================================================

library(readr)
library(dplyr)
library(tidyr)
library(janitor)
library(stringr)
library(lubridate)
library(here)

set.seed(20210101) # fixes every random draw so the file reproduces exactly

hartford_county <- c(
  "Avon",
  "Berlin",
  "Bloomfield",
  "Bristol",
  "Burlington",
  "Canton",
  "East Granby",
  "East Hartford",
  "East Windsor",
  "Enfield",
  "Farmington",
  "Glastonbury",
  "Granby",
  "Hartford",
  "Hartland",
  "Manchester",
  "Marlborough",
  "New Britain",
  "Newington",
  "Plainville",
  "Rocky Hill",
  "Simsbury",
  "Southington",
  "South Windsor",
  "Suffield",
  "West Hartford",
  "Wethersfield",
  "Windsor",
  "Windsor Locks"
)

# --- 1. Real counts: new cases per town per report date ----------------------
counts <-
  read_csv(here("data", "raw", "ct_covid_by_town_2026-06-30.csv")) |>
  clean_names() |>
  mutate(
    report_date = mdy(last_update_date),
    town = str_to_title(str_trim(town)),
    total_cases = parse_number(as.character(total_cases))
  ) |>
  filter(town %in% hartford_county) |>
  arrange(town, report_date) |>
  group_by(town) |>
  mutate(new_cases = total_cases - lag(total_cases)) |>
  ungroup() |>
  mutate(new_cases = pmax(new_cases, 0)) |>
  filter(
    report_date >= as.Date("2020-12-01"),
    report_date <= as.Date("2021-01-31"),
    !is.na(new_cases),
    new_cases > 0
  ) |>
  select(town, report_date, new_cases)

# --- 2. Expand counts into one row per case ----------------------------------
linelist <- counts |>
  uncount(new_cases) |>
  mutate(case_id = sprintf("HC-%06d", row_number()))

n <- nrow(linelist)

# --- 3. Simulate demographics and outcomes (all proportions illustrative) ----
linelist <- linelist |>
  mutate(
    age = pmin(pmax(round(rnorm(n, mean = 42, sd = 22)), 0L), 100L),
    sex = sample(c("Female", "Male"), n, replace = TRUE, prob = c(0.51, 0.49)),
    race_ethnicity = sample(
      c(
        "White, non-Hispanic",
        "Hispanic or Latino",
        "Black, non-Hispanic",
        "Asian/Pacific Islander, non-Hispanic",
        "Other/Multiracial, non-Hispanic",
        "Unknown"
      ),
      n,
      replace = TRUE,
      prob = c(0.55, 0.18, 0.14, 0.05, 0.04, 0.04)
    ),
    onset_date = report_date - sample(3:14, n, replace = TRUE),
    hosp_prob = case_when(
      age < 18 ~ 0.01,
      age < 50 ~ 0.02,
      age < 65 ~ 0.06,
      age < 80 ~ 0.15,
      TRUE ~ 0.30
    ),
    hospitalized = if_else(rbinom(n, 1, hosp_prob) == 1, "Yes", "No"),
    hosp_admit_date = if_else(
      hospitalized == "Yes",
      onset_date + sample(2:8, n, replace = TRUE),
      as.Date(NA)
    ),
    los_days = if_else(
      hospitalized == "Yes",
      sample(2:21, n, replace = TRUE),
      NA_integer_
    ),
    hosp_discharge_date = hosp_admit_date + los_days,
    death_prob = pmin(
      case_when(
        age < 40 ~ 0.001,
        age < 65 ~ 0.010,
        age < 80 ~ 0.060,
        TRUE ~ 0.180
      ) *
        if_else(hospitalized == "Yes", 3, 1),
      0.6
    ),
    died = if_else(rbinom(n, 1, death_prob) == 1, "Yes", "No"),
    death_date = if_else(
      died == "Yes",
      report_date + sample(5:30, n, replace = TRUE),
      as.Date(NA)
    )
  ) |>
  select(
    case_id,
    town,
    age,
    sex,
    race_ethnicity,
    onset_date,
    report_date,
    hospitalized,
    hosp_admit_date,
    hosp_discharge_date,
    died,
    death_date
  )

# --- 4. Write it out ---------------------------------------------------------
write_csv(linelist, here("data", "synthetic-covid-linelist.csv"))

cat(
  "Wrote",
  nrow(linelist),
  "synthetic cases to data/synthetic-covid-linelist.csv\n"
)
