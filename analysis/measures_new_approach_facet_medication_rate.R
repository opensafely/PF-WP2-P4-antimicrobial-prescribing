
# Prescribing rates with Statistical Disclosure Control (SDC)

library(tidyverse)
library(here)
library(patchwork)

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

measure_pattern <- paste0(
  "^(gp|pf)_medication_(",
  paste(conditions, collapse = "|"),
  ")$"
)

# -----------------------------------------------------------------------------
# 2. Monthly prescribing rates
#    Aggregate numerators and denominators before calculating rates
# -----------------------------------------------------------------------------

rates_monthly <- measures_new_approach %>%
  filter(str_detect(measure, measure_pattern)) %>%
  group_by(interval_start, measure) %>%
  summarise(
    numerator   = sum(numerator, na.rm = TRUE),
    denominator = sum(denominator, na.rm = TRUE),
    .groups = "drop"
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
    ),
    prescribing_rate = if_else(
      denominator > 0,
      1000 * numerator / denominator,
      NA_real_
    )
  )

# -----------------------------------------------------------------------------
# 3. Apply SDC
#
# GP: all dates
# PF: from February 2024 onwards
# Suppression threshold: numerator < 8
# -----------------------------------------------------------------------------

rates_monthly_sdc <- rates_monthly %>%
  mutate(
    sdc_required = numerator < 8 &
      (
        Setting == "GP" |
          (
            Setting == "PF" &
              interval_start >= PF_start
          )
      ),
    numerator_sdc = if_else(
      sdc_required,
      NA_real_,
      as.numeric(numerator)
    ),
    denominator_sdc = if_else(
      sdc_required,
      NA_real_,
      as.numeric(denominator)
    ),
    prescribing_rate_sdc = if_else(
      sdc_required,
      NA_real_,
      prescribing_rate
    )
  )

message(
  "Number of monthly cells suppressed: ",
  sum(rates_monthly_sdc$sdc_required, na.rm = TRUE)
)

# -----------------------------------------------------------------------------
# 4. Plot monthly prescribing rates after SDC
# -----------------------------------------------------------------------------

facet_rates_plot_sdc <- ggplot(
  rates_monthly_sdc,
  aes(
    x = interval_start,
    y = prescribing_rate_sdc,
    group = Setting,
    color = Setting,
    shape = Setting
  )
) +
  geom_line(linewidth = 0.5, na.rm = FALSE) +
  geom_point(size = 1.0, na.rm = TRUE) +
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
    subtitle = "Rates subject to statistical disclosure control",
    x = "Month",
    y = "Prescribing rate (per 1,000 eligible population)",
    color = "Setting",
    shape = "Setting"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

print(facet_rates_plot_sdc)

# -----------------------------------------------------------------------------
# 5. Save controlled plot
# -----------------------------------------------------------------------------

ggsave(
  filename = here(
    "output",
    "measures_new_approach_facet_medication_rate.png"
  ),
  plot = facet_rates_plot_sdc,
  width = 10,
  height = 6,
  dpi = 300
)

# -----------------------------------------------------------------------------
# 6. Export controlled CSV
# -----------------------------------------------------------------------------

rates_monthly_release <- rates_monthly_sdc %>%
  transmute(
    interval_start,
    Setting,
    condition,
    numerator = if_else(
      sdc_required,
      "[Redacted]",
      as.character(numerator)
    ),
    denominator = if_else(
      sdc_required,
      "[Redacted]",
      as.character(denominator)
    ),
    prescribing_rate = if_else(
      sdc_required,
      "[Redacted]",
      as.character(prescribing_rate)
    )
  ) %>%
  arrange(Setting, interval_start, condition)

write_csv(
  rates_monthly_release,
  here(
    "output",
    "measures_new_approach_facet_medication_rate.csv"
  )
)

# -----------------------------------------------------------------------------
# 7. Internal SDC audit
# -----------------------------------------------------------------------------

sdc_audit <- rates_monthly_sdc %>%
  group_by(Setting, condition) %>%
  summarise(
    total_months = n(),
    suppressed_months = sum(sdc_required, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(Setting, condition)

print(sdc_audit, n = Inf)

message("SDC-controlled prescribing-rate outputs have been created.")
