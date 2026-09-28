# =============================================================================
# Pharmacy First — Practice measures
# Figure 20. Monthly medication counts by condition and setting (GP vs PF),
#            faceted by PF condition
# Author: Arnaud Iradukunda
# =============================================================================

library(tidyverse)
library(here)

# -----------------------------------------------------------------------------
# 1. Data
#    practice_measures is in long format:
#    measure, interval_start, interval_end, ratio, numerator, denominator, practice
# -----------------------------------------------------------------------------
practice_measures <- read_csv(
  here("output", "practice_measures.csv")
) %>%
  mutate(interval_start = as.Date(interval_start))

# GP Connect date (vertical line)
GP_connect <- as.Date("2025-10-01")

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
# 2. Monthly totals across practices
#    The medication count is the numerator of the gp_medication_* and
#    pf_medication_* measures. Summing it by month and measure gives the
#    monthly totals across practices, already in long format for plotting.
# -----------------------------------------------------------------------------
all_conditions_monthly <- practice_measures %>%
  filter(
    str_detect(
      measure,
      paste0("^(gp|pf)_medication_(", paste(conditions, collapse = "|"), ")$")
    )
  ) %>%
  group_by(interval_start, measure) %>%
  summarise(
    medication_count = sum(numerator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  extract(
    measure,
    into  = c("Setting", "condition"),
    regex = "^(gp|pf)_medication_(.*)$"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp" ~ "GP",
      Setting == "pf" ~ "PF"
    ),
    condition = case_when(
      condition == "uti"            ~ "UTI",
      condition == "sinusitis"      ~ "Sinusitis",
      condition == "insectbite"     ~ "Insect bites",
      condition == "otitismedia"    ~ "Otitis media",
      condition == "sorethroat"     ~ "Sore throat",
      condition == "shingles"       ~ "Shingles",
      condition == "impetigo"       ~ "Impetigo",
      condition == "all_conditions" ~ "All PF conditions"
    )
  )

# -----------------------------------------------------------------------------
# 3. Faceted plot
# -----------------------------------------------------------------------------
faceted_counts_plot <- ggplot(
  all_conditions_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting,
    shape = Setting
  )
) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  facet_wrap(
    ~ condition,
    scales = "free_y",
    ncol = 2
  ) +
  scale_x_date(
    date_labels = "%Y-%m",
    date_breaks = "1 months"
  ) +
  labs(
    title = "Monthly medication counts by condition and setting",
    x = "Month",
    y = "Medication count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

faceted_counts_plot

# -----------------------------------------------------------------------------
# 4. Save as PNG
# -----------------------------------------------------------------------------
ggsave(
  filename = here("output", "results_5_Fig20_faceted_counts_by_condition.png"),
  plot = faceted_counts_plot,
  width = 10,
  height = 6,
  dpi = 300
)
