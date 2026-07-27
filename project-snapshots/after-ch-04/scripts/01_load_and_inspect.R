# 01_load_and_inspect.R
# Load the raw CT COVID-19 by-town CSV and take a first look.

library(dplyr)
library(readr)
library(here)

csv_path <- here("data", "raw", "ct_covid_by_town_2026-06-30.csv")

covid_data <- read_csv(csv_path)

head(covid_data)
glimpse(covid_data)
