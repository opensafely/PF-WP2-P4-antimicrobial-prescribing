
# Prescribing rates with Statistical Disclosure Control (SDC)
#
# SDC rules:
#   1. Counts 1-7 are redacted (NA).
#   2. Zero remains zero.
#   3. Counts >= 8 are rounded to nearest 5.
#   4. Rates are calculated ONLY from SDC-controlled counts.
#   5. Raw counts and raw rates are never released.
#   6. Existing PNG and CSV filenames are retained.

library(tidyverse)
library(here)
library(patchwork)

# 0. SDC function
apply_sdc <- function(x) {
  case_when(
    is.na(x) ~ NA_real_,
    x == 0 ~ 0,
    x < 8 ~ NA_real_,
    x >= 8 ~ round(x / 5) * 5
  )
}

# 1. Data

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

# 2. Monthly numerators and denominators (raw)
# Aggregate before applying SDC.

rates_monthly <- measures_new_approach %>%
  filter(str_detect(measure, measure_pattern)) %>%
  group_by(interval_start, measure) %>%
  summarise(
    numerator   = sum(numerator, na.rm = TRUE), # Accross all the practices
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
    )
  )

# 3. Apply SDC and calculate controlled rates

rates_monthly_sdc <- rates_monthly %>%
  mutate(
    numerator_sdc   = apply_sdc(numerator),
    denominator_sdc = apply_sdc(denominator),

    # Calculate rate only when both counts are releasable.
    prescribing_rate_sdc_derived = if_else(
      !is.na(numerator_sdc) &
        !is.na(denominator_sdc) &
        denominator_sdc > 0,
      1000 * numerator_sdc / denominator_sdc,
      NA_real_
    ),

    # Internal audit flags (never released).
    numerator_redacted = numerator > 0 & numerator < 8,
    denominator_redacted = denominator > 0 & denominator < 8
  )

message(
  "Numerators redacted: ",
  sum(rates_monthly_sdc$numerator_redacted, na.rm = TRUE)
)

message(
  "Denominators redacted: ",
  sum(rates_monthly_sdc$denominator_redacted, na.rm = TRUE)
)

# 4. Plot monthly prescribing rates after SDC

facet_rates_plot_sdc <- ggplot(
  rates_monthly_sdc,
  aes(
    x = interval_start,
    y = prescribing_rate_sdc_derived,
    group = Setting,
    color = Setting,
    shape = Setting
  )
) +
  geom_line(linewidth = 0.5, na.rm = TRUE) +
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

# 5. Save controlled plot (original filename retained)

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

# 6. Export controlled CSV (original filename retained)

rates_monthly_release <- rates_monthly_sdc %>%
  transmute(
    interval_start,
    Setting,
    condition,
    numerator_sdc,
    denominator_sdc,
    prescribing_rate_sdc_derived =
      round(prescribing_rate_sdc_derived, 4)
  ) %>%
  arrange(Setting, interval_start, condition)

write_csv(
  rates_monthly_release,
  here(
    "output",
    "measures_new_approach_facet_medication_rate_sdc.csv"
  )
)

# 7. Internal SDC audit (do not release)

sdc_audit <- rates_monthly_sdc %>%
  group_by(Setting, condition) %>%
  summarise(
    total_months = n(),
    numerator_redacted_months =
      sum(numerator_redacted, na.rm = TRUE),
    denominator_redacted_months =
      sum(denominator_redacted, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(Setting, condition)

print(sdc_audit, n = Inf)

# 8. Validation checks

# No released non-zero count can be below 8.
stopifnot(
  all(
    is.na(rates_monthly_sdc$numerator_sdc) |
      rates_monthly_sdc$numerator_sdc == 0 |
      rates_monthly_sdc$numerator_sdc >= 10
  ),
  all(
    is.na(rates_monthly_sdc$denominator_sdc) |
      rates_monthly_sdc$denominator_sdc == 0 |
      rates_monthly_sdc$denominator_sdc >= 10
  )
)

# All released non-zero counts must be multiples of 5.
stopifnot(
  all(
    is.na(rates_monthly_sdc$numerator_sdc) |
      rates_monthly_sdc$numerator_sdc %% 5 == 0
  ),
  all(
    is.na(rates_monthly_sdc$denominator_sdc) |
      rates_monthly_sdc$denominator_sdc %% 5 == 0
  )
)

message(
  "SDC-controlled prescribing-rate outputs have been created successfully."
)
