# ============================================================================
# 02_describe_and_test.R
#
# Descriptives, cross-tabulation, and statistical tests on the SYNTHETIC
# line-list from 01_make_synthetic_linelist.R. Runs on fake data — the
# patterns are real-shaped, but no row is a real person. See the
# "Describing and Testing" chapter for the walk-through.
#
# Reads: data/synthetic-covid-linelist.csv
# ============================================================================

library(readr)
library(dplyr)
library(janitor)
library(here)

linelist <-
  read_csv(here("data", "synthetic-covid-linelist.csv")) |>
  mutate(
    age_group = case_when(
      age < 18 ~ "0-17",
      age < 50 ~ "18-49",
      age < 65 ~ "50-64",
      age < 80 ~ "65-79",
      TRUE ~ "80+"
    )
  )

# --- Descriptives ------------------------------------------------------------
print(
  linelist |>
    tabyl(died) |>
    adorn_pct_formatting()
)

print(
  linelist |>
    group_by(died) |>
    summarise(
      n = n(),
      mean_age = round(mean(age), 1),
      median_age = median(age),
      min_age = min(age),
      max_age = max(age)
    )
)

# --- Cross-tabulation with row percents --------------------------------------
print(
  linelist |>
    tabyl(age_group, died) |>
    adorn_totals("row") |>
    adorn_percentages("row") |>
    adorn_pct_formatting() |>
    adorn_ns()
)

# --- Chi-square: is age group associated with death? -------------------------
age_died <- table(linelist$age_group, linelist$died)
print(chisq.test(age_died))

# --- Fisher's exact: for small/sparse tables (one small town) ----------------
hartland <- linelist |> filter(town == "Hartland")
print(table(hartland$hospitalized, hartland$died))
print(fisher.test(table(hartland$hospitalized, hartland$died)))

# --- Trend in proportions: does CFR climb across ordered age groups? ---------
cfr_by_age <-
  linelist |>
  group_by(age_group) |>
  summarise(deaths = sum(died == "Yes"), n = n()) |>
  arrange(age_group)

print(cfr_by_age)
print(prop.trend.test(cfr_by_age$deaths, cfr_by_age$n))
