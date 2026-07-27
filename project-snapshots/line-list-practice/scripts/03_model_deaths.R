# ============================================================================
# 03_model_deaths.R
#
# Logistic regression for ADJUSTED odds ratios on the SYNTHETIC line-list.
# Runs on fake data. See the "Modeling: Adjusted Effect Estimates" chapter.
#
# Reads: data/synthetic-covid-linelist.csv
# Needs: broom  (install.packages("broom") if you don't have it)
# ============================================================================

library(readr)
library(dplyr)
library(broom)
library(here)

model_data <-
  read_csv(here("data", "synthetic-covid-linelist.csv")) |>
  mutate(
    age_group = factor(
      case_when(
        age < 18 ~ "0-17",
        age < 50 ~ "18-49",
        age < 65 ~ "50-64",
        age < 80 ~ "65-79",
        TRUE ~ "80+"
      ),
      levels = c("18-49", "0-17", "50-64", "65-79", "80+")
    ),
    died_flag = as.integer(died == "Yes")
  )

# --- Fit: death explained by age group, sex, and hospitalization -------------
model <- glm(
  died_flag ~ age_group + sex + hospitalized,
  data = model_data,
  family = binomial
)

print(summary(model))

# --- Odds ratios with 95% confidence intervals -------------------------------
# exponentiate = TRUE turns log-odds coefficients into odds ratios.
print(tidy(model, exponentiate = TRUE, conf.int = TRUE))
