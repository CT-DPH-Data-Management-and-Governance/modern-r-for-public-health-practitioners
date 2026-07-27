# 05_briefing_charts.R
# This week's briefing deck: a Hartford-vs-statewide trend chart and a
# statewide test-positivity map, both saved to outputs/figures/.

library(dplyr)
library(readr)
library(here)
library(ggplot2)
library(sf)
library(tigris)

covid_clean <- read_csv(here("data", "processed", "covid_clean.csv"))

# --- Hartford vs. the statewide average --------------------------------

hartford_trend <-
  covid_clean |>
  filter(town == "Hartford") |>
  select(last_update_date, new_cases) |>
  mutate(series = "Hartford")

statewide_trend <-
  covid_clean |>
  group_by(last_update_date) |>
  summarise(new_cases = mean(new_cases, na.rm = TRUE)) |>
  mutate(series = "Statewide Average")

combined_trend <- bind_rows(hartford_trend, statewide_trend)

ggplot(
  data = combined_trend,
  mapping = aes(x = last_update_date, y = new_cases, color = series)
) +
  geom_line(linewidth = 1) +
  scale_color_manual(
    name = NULL,
    values = c("Hartford" = "#3371E7", "Statewide Average" = "gray50")
  ) +
  labs(
    title = "Hartford New Cases vs. Statewide Average",
    subtitle = "Daily count from report to report",
    x = NULL,
    y = "New Cases"
  ) +
  theme_classic()

ggsave(
  here("outputs", "figures", "hartford_vs_state_trend.png"),
  width = 7,
  height = 4,
  dpi = 300
)

# --- statewide test positivity map -------------------------------------

ct_towns <-
  county_subdivisions(
    state = "09",
    cb = TRUE,
    progress_bar = FALSE
  )

latest_date <- max(covid_clean$last_update_date)

# positivity answers a different question than case rate: of everyone
# tested, what share came back positive?
town_positivity <-
  covid_clean |>
  filter(last_update_date == latest_date) |>
  mutate(positivity = number_of_positives / number_of_tests * 100) |>
  select(town, positivity)

ct_bounded <-
  ct_towns |>
  left_join(town_positivity, by = join_by(NAME == town))

ggplot() +
  geom_sf(
    data = ct_bounded[is.na(ct_bounded$positivity), ],
    fill = "gray95",
    color = "white",
    linewidth = 0.1
  ) +
  geom_sf(
    data = ct_bounded[!is.na(ct_bounded$positivity), ],
    mapping = aes(fill = positivity),
    color = "white",
    linewidth = 0.1
  ) +
  scale_fill_gradient2(
    low = "#C6D4FB",
    mid = "#7094F5",
    high = "#00214D",
    midpoint = mean(ct_bounded$positivity, na.rm = TRUE),
    na.value = "gray95",
    name = "Test Positivity\n(%)"
  ) +
  labs(
    title = "COVID-19 Test Positivity by Town",
    subtitle = paste("As of", latest_date),
    fill = NULL
  ) +
  theme_void() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray50"),
    legend.position = "right"
  )

ggsave(
  here("outputs", "figures", "statewide_positivity_map.png"),
  width = 7,
  height = 5,
  dpi = 300
)

# --- the short list ----------------------------------------------------

town_positivity |>
  slice_max(positivity, n = 5)

town_positivity |>
  slice_min(positivity, n = 5)
