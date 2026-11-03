# Prescribing rates with Statistical Disclosure Control (SDC)
#
# SDC rules (OpenSAFELY guidance for rates; all settings, all dates):
#   1. Numerators and denominators rounded to MIDPOINT 6:
#      0 -> 0, 1-6 -> 3, 7-12 -> 9, 13-18 -> 15, ...
#      (no separate redaction needed: values 1-6 are never released)
#   2. Rates calculated ONLY from the midpoint-6 numerator and denominator
#   3. Naming convention: rounded columns end in _midpoint6, values derived
#      from them end in _midpoint6_derived
# Midpoint 6 rounding is applied in: roundmid_any() and section 3.

library(tidyverse)
library(here)
library(patchwork)

# 0. SDC helper: midpoint 6 rounding (from the OpenSAFELY SDC documentation)

roundmid_any <- function(x, to = 6) {
  # like round_any, but centers on (integer) midpoint of the rounding points
  ceiling(x / to) * to - (floor(to / 2) * (x != 0))
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
#    Aggregate numerators and denominators before calculating rates

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
    )
  )

# 3. Apply SDC: midpoint 6 rounding, then calculate rates
#    Raw numerators, denominators and rates are never plotted or written out.

rates_monthly_sdc <- rates_monthly %>%
  mutate(
    numerator_midpoint6   = roundmid_any(numerator),
    denominator_midpoint6 = roundmid_any(denominator),

    prescribing_rate_midpoint6_derived = if_else(
      denominator_midpoint6 > 0,
      1000 * numerator_midpoint6 / denominator_midpoint6,
      NA_real_
    ),

    # Months whose true numerator was 1-6 (released as 3), for the audit only
    low_numerator = numerator > 0 & numerator <= 6
  )

message(
  "Number of monthly cells with numerator 1-6 (released as 3): ",
  sum(rates_monthly_sdc$low_numerator, na.rm = TRUE)
)

# 4. Plot monthly prescribing rates after SDC

facet_rates_plot_sdc <- ggplot(
  rates_monthly_sdc,
  aes(
    x = interval_start,
    y = prescribing_rate_midpoint6_derived,
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

# 5. Save controlled plot

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

# 6. Export controlled CSV (midpoint 6 numerators/denominators and derived rates)

rates_monthly_release <- rates_monthly_sdc %>%
  transmute(
    interval_start,
    Setting,
    condition,
    numerator_midpoint6,
    denominator_midpoint6,
    prescribing_rate_midpoint6_derived = round(prescribing_rate_midpoint6_derived, 4)
  ) %>%
  arrange(Setting, interval_start, condition)

write_csv(
  rates_monthly_release,
  here(
    "output",
    "measures_new_approach_facet_medication_rate_sdc.csv"
  )
)

# 7. Internal SDC audit (month counts only)

sdc_audit <- rates_monthly_sdc %>%
  group_by(Setting, condition) %>%
  summarise(
    total_months = n(),
    low_numerator_months = sum(low_numerator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(Setting, condition)

print(sdc_audit, n = Inf)

# Every released non-zero value must be 3, 9, 15, ... (i.e. 3 mod 6)
stopifnot(
  all(rates_monthly_sdc$numerator_midpoint6 %in% 0 |
        rates_monthly_sdc$numerator_midpoint6 %% 6 == 3, na.rm = TRUE),
  all(rates_monthly_sdc$denominator_midpoint6 %in% 0 |
        rates_monthly_sdc$denominator_midpoint6 %% 6 == 3, na.rm = TRUE)
)

message("SDC-controlled prescribing-rate outputs have been created.")