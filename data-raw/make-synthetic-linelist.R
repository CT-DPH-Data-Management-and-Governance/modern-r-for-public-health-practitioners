# ============================================================================
# make-synthetic-linelist.R
#
# ***  SYNTHETIC DATA — NOT REAL.  DO NOT TREAT AS ACTUAL DPH RECORDS.  ***
#
# Builds a FAKE COVID-19 line-list (one row per case) for teaching data
# manipulation. It is anchored to REAL CT DPH town-level case counts
# (Open Data Portal dataset 28fr-iqnx), scoped to Hartford County during the
# winter 2020-2021 surge, then expanded to one row per case with SIMULATED
# demographics and outcomes. No row is a real person; every demographic and
# outcome value is drawn from a random distribution, not observed.
#
# The real counts control HOW MANY cases each town had on each report date.
# Everything else — age, sex, race/ethnicity, onset date, hospitalization,
# death — is invented and calibrated only to be *plausible*, not accurate.
#
# Deterministic: the set.seed() below fixes every random draw, so re-running
# reproduces the same file exactly. Change the seed and you get a different
# (still fake) cohort.
#
# Produces: data/synthetic-covid-linelist.csv
# ============================================================================

library(readr)
library(dplyr)
library(tidyr)
library(janitor)
library(stringr)
library(lubridate)

set.seed(20210101) # a date from the wave we're modeling; any fixed value works

# The 29 towns of Hartford County (the ARCHIVE dataset predates the switch to
# planning regions, so it still reports by the old eight counties).
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

window_start <- as.Date("2020-12-01")
window_end <- as.Date("2021-01-31")

# --- 1. Real counts: new cases per town per report date ----------------------
# Total cases is cumulative, so daily new cases is the change from the prior
# report. Negative blips (state revising an old total) get floored at zero —
# you can't expand a negative number of people.
counts <-
  read_csv(
    here::here("data", "ct-covid-by-town-2026-06-30.csv"),
    show_col_types = FALSE
  ) |>
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
    report_date >= window_start,
    report_date <= window_end,
    !is.na(new_cases),
    new_cases > 0
  ) |>
  select(town, report_date, new_cases)

# --- 2. Expand counts into one row per case ----------------------------------
linelist <- counts |>
  uncount(new_cases) |>
  mutate(case_id = sprintf("HC-%06d", row_number()))

n <- nrow(linelist)

# --- 3. Simulate demographics and outcomes -----------------------------------
# All proportions below are illustrative, not measured. They give a realistic
# *shape* (COVID skews older for severe outcomes) without claiming accuracy.
linelist <- linelist |>
  mutate(
    # Age: centered on mid-adult, clamped to a human range.
    age = pmin(pmax(round(rnorm(n, mean = 42, sd = 22)), 0L), 100L),

    sex = sample(
      c("Female", "Male"),
      n,
      replace = TRUE,
      prob = c(0.51, 0.49)
    ),

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

    # Symptom onset precedes the report by a reporting delay.
    onset_date = report_date - sample(3:14, n, replace = TRUE),

    # Hospitalization risk climbs steeply with age.
    hosp_prob = case_when(
      age < 18 ~ 0.01,
      age < 50 ~ 0.02,
      age < 65 ~ 0.06,
      age < 80 ~ 0.15,
      TRUE ~ 0.30
    ),
    hospitalized = if_else(rbinom(n, 1, hosp_prob) == 1, "Yes", "No"),

    # Admission a few days after onset; discharge after a length of stay.
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

    # Death risk climbs with age and is higher among the hospitalized.
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
  )

# --- 4. Final column order (drop the intermediate probability helpers) -------
linelist <- linelist |>
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

# --- 5. Write it out ---------------------------------------------------------
out_path <- here::here("data", "synthetic-covid-linelist.csv")
write_csv(linelist, out_path)

# --- 6. Validation summary (printed, not saved) ------------------------------
cat("Rows (cases):", nrow(linelist), "\n")
cat("Towns:", dplyr::n_distinct(linelist$town), "\n")
cat(
  "Report date range:",
  as.character(min(linelist$report_date)),
  "to",
  as.character(max(linelist$report_date)),
  "\n"
)
cat(
  "Age: min",
  min(linelist$age),
  "median",
  median(linelist$age),
  "max",
  max(linelist$age),
  "\n"
)
cat(sprintf(
  "Hospitalized: %.1f%%\n",
  100 * mean(linelist$hospitalized == "Yes")
))
cat(sprintf("Died (CFR): %.2f%%\n", 100 * mean(linelist$died == "Yes")))
cat("Wrote:", out_path, "\n")
