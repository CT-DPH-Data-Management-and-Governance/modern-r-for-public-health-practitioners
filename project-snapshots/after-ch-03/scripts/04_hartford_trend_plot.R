# 04_hartford_trend_plot.R
# The Hartford new-case chart built in the Data Visualization lesson.

library(dplyr)
library(readr)
library(here)
library(janitor)
library(lubridate)
library(ggplot2)

covid_clean <- read_csv(here("data", "processed", "covid_clean.csv"))

hartford <-
  covid_clean |>
  filter(town == "Hartford") |>
  select(date = last_update_date, total_cases, total_deaths, new_cases) |>
  arrange(date)

ggplot(data = hartford, mapping = aes(x = date, y = new_cases)) +
  geom_point(color = "#3371E7", size = 2, alpha = 0.1) +
  geom_line(color = "#3371E7", linewidth = 0.5) +
  labs(
    title = "New COVID-19 Cases - Hartford",
    subtitle = "Daily count from report to report",
    x = NULL,
    y = "New Cases on Each Date",
    caption = "Source: CT DPH COVID-19 open data"
  ) +
  theme_classic() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray50")
  )

ggsave(
  here("outputs", "figures", "hartford_new_cases.png"),
  width = 7,
  height = 4,
  dpi = 300
)
