
#Prescribing rates

library(tidyverse)
library(here)
library(patchwork)   # added: to put the two practice-level graphs side by side
# -----------------------------------------------------------------------------
# 1. Data
# -----------------------------------------------------------------------------
measures_new_approach <- read_csv(
  here("output", "measures_new_approach_medication.csv"),
  show_col_types = FALSE
) %>%
  mutate(interval_start = as.Date(interval_start))

GP_connect <- as.Date("2025-10-01")
PF_start   <- as.Date("2024-02-01")

# Conditions to include
conditions <- c(
  "uti",
  "sinusitis",
  "insectbite",
  "otitismedia",
  "sorethroat",
  "shingles",
  "impetigo",
  "all_conditions"
)

# -----------------------------------------------------------------------------
# 2. Monthly prescribing rates by condition and setting
#   Here, we  aggregated numerators and denominators before calculating rates.
# -----------------------------------------------------------------------------
rates_monthly <- measures_new_approach %>%
  filter(
    str_detect(
      measure,
      paste0(
        "^(gp|pf)_medication_(",
        paste(conditions, collapse = "|"),
        ")$"
      )
    )
  ) %>%
  group_by(interval_start, measure) %>%
  summarise(
    numerator   = sum(numerator, na.rm = TRUE),
    denominator = sum(denominator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    prescribing_rate = if_else(
      denominator > 0,
      1000 * numerator / denominator,
      NA_real_
    )
  ) %>%
  extract(
    measure,
    into = c("Setting", "condition"),
    regex = "^(gp|pf)_medication_(.*)$"
  ) %>%
  mutate(
    Setting = recode(Setting, gp = "GP", pf = "PF"),
    condition = recode(
      condition,
      uti            = "UTI",
      sinusitis      = "Sinusitis",
      insectbite     = "Insect bites",
      otitismedia    = "Otitis media",
      sorethroat     = "Sore throat",
      shingles       = "Shingles",
      impetigo       = "Impetigo",
      all_conditions = "All PF conditions"
    )
  )


# 3. Plot monthly prescribing rates

facet_rates_plot <- ggplot(
  rates_monthly,
  aes(
    x = interval_start,
    y = prescribing_rate,
    group = Setting,
    color = Setting,
    shape = Setting
  )
) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 1.0) +
  geom_vline(
    xintercept = PF_start,
    linetype = "dashed",
    linewidth = 0.4,
    color = "blue"
  ) +
  geom_vline(
    xintercept = GP_connect,
    linetype = "dashed",
    linewidth = 0.4
  ) +
  facet_wrap(
    ~ condition,
    scales = "free_y",
    ncol = 2
  ) +
  scale_x_date(
    date_labels = "%Y-%m",
    date_breaks = "2 months"
  ) +
  labs(
    title = "Monthly prescribing rates by condition and setting",
    #subtitle = paste( "Blue dashed line: Pharmacy First launch;", "black dashed line: GP Connect introduction"),
    x = "Month",
    y = "Prescribing rate (per 1000 eligible population)",
    color = "Setting",
    shape = "Setting"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

print(facet_rates_plot)


# 4. Save plot

ggsave(
  filename = here("output", "measures_new_approach_facet_medication_rate.png"),
  plot = facet_rates_plot,
  width = 10,
  height = 6,
  dpi = 300
)

# Save the data used for the prescribing rates graph
write_csv(
  rates_monthly,
  here("output", "measures_new_approach_facet_medication_rate.csv")
)
