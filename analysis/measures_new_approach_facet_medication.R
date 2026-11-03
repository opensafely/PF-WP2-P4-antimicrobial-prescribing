# Monthly medication counts by condition and setting
# Statistical Disclosure Control (SDC) - OpenSAFELY guidance
#
# SDC rules (all settings, all dates):
#   1. Counts <= 7 redacted ("[REDACTED]"); zeros retained
#   2. All remaining counts rounded to the nearest 5
# Same rule as the other medication scripts, so released files are consistent
# and rounding protects against differencing (e.g. All PF conditions minus
# the individual conditions).
#
# Outputs:
#   - Controlled monthly CSV
#   - Controlled monthly line plot (PNG)

library(tidyverse)
library(here)
library(lubridate)
library(scales)

# 0. SDC helpers

sdc_threshold <- 7
sdc_base <- 5

sdc_count <- function(x, threshold = sdc_threshold, base = sdc_base) {
  case_when(
    is.na(x) ~ NA_real_,
    x == 0 ~ 0,
    x <= threshold ~ NA_real_,
    TRUE ~ round(x / base) * base
  )
}

sdc_redacted <- function(x, threshold = sdc_threshold) {
  !is.na(x) & x > 0 & x <= threshold
}

# 1. Read data

measures_new_approach <- read_csv(
  here("output", "measures_new_approach_medication.csv"),
  show_col_types = FALSE
) %>%
  mutate(
    interval_start = as.Date(interval_start)
  )

# Important dates
GP_connect <- as.Date("2025-10-01")
PF_start   <- as.Date("2024-02-01")

message("Number of rows: ", nrow(measures_new_approach))
message("Number of columns: ", ncol(measures_new_approach))
message(
  "Date range: ",
  min(measures_new_approach$interval_start, na.rm = TRUE),
  " to ",
  max(measures_new_approach$interval_start, na.rm = TRUE)
)

# 2. Define conditions

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

# 3. Monthly medication counts by condition and setting

numerators_monthly <- measures_new_approach %>%
  filter(
    str_detect(measure, measure_pattern)
  ) %>%
  group_by(interval_start, measure) %>%
  summarise(
    medication_count = sum(numerator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  extract(
    measure,
    into = c("Setting", "condition"),
    regex = "^(gp|pf)_medication_(.*)$"
  ) %>%
  mutate(
    Setting = recode(
      Setting,
      gp = "GP",
      pf = "PF"
    ),
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

# Keep original numeric data unchanged for analysis (never written out).
# 4. Apply SDC: redact <= 7, round the rest to the nearest 5

numerators_monthly_sdc <- numerators_monthly %>%
  mutate(
    sdc_required = sdc_redacted(medication_count),
    medication_count_sdc = sdc_count(medication_count)
  )

# Report the number of cells redacted
message(
  "Number of monthly cells redacted: ",
  sum(numerators_monthly_sdc$sdc_required, na.rm = TRUE)
)

# 5. Export controlled monthly CSV (rounded counts only)

monthly_release <- numerators_monthly_sdc %>%
  mutate(
    medication_count = if_else(
      sdc_required,
      "[REDACTED]",
      as.character(medication_count_sdc)
    )
  ) %>%
  select(
    interval_start,
    Setting,
    condition,
    medication_count
  ) %>%
  arrange(
    Setting,
    interval_start,
    condition
  )

write_csv(
  monthly_release,
  here(
    "output",
    "measures_new_approach_facet_medication.csv"
  )
)

# 6. Plot controlled monthly medication counts

facet_numerators_plot_sdc <- ggplot(
  numerators_monthly_sdc,
  aes(
    x = interval_start,
    y = medication_count_sdc,
    group = Setting,
    color = Setting,
    shape = Setting
  )
) +
  geom_line(
    linewidth = 0.5,
    na.rm = FALSE
  ) +
  geom_point(
    size = 1.0,
    na.rm = TRUE
  ) +
  geom_vline(
    xintercept = GP_connect,
    linetype = "dashed",
    linewidth = 0.3
  ) +
  geom_vline(
    xintercept = PF_start,
    linetype = "dashed",
    linewidth = 0.3,
    color = "blue"
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
  scale_y_continuous(
    labels = comma
  ) +
  labs(
    title = "Monthly medication counts by condition and setting",
    subtitle = paste(
      "Statistical disclosure control applied:",
      "counts \u22647 redacted; all other counts rounded to the nearest 5"
    ),
    x = "Month",
    y = "Medication count",
    color = "Setting",
    shape = "Setting",
    caption = paste(
      "Suppressed counts are displayed as gaps.",
      "Dashed blue line: Pharmacy First launch;",
      "dashed black line: GP Connect implementation."
    )
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(
      angle = 0,
      hjust = 1
    ),
    strip.text = element_text(
      face = "bold"
    )
  )

print(facet_numerators_plot_sdc)

# 7. Save controlled PNG

ggsave(
  filename = here(
    "output",
    "measures_new_approach_facet_medication.png"
  ),
  plot = facet_numerators_plot_sdc,
  width = 10,
  height = 6,
  dpi = 300
)

# 8. SDC audit summary (for internal review; month counts only)

sdc_audit <- numerators_monthly_sdc %>%
  group_by(Setting, condition) %>%
  summarise(
    total_months = n(),
    suppressed_months = sum(sdc_required, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(Setting, condition)

print(sdc_audit, n = Inf)

stopifnot(
  all(numerators_monthly_sdc$medication_count_sdc %% sdc_base == 0, na.rm = TRUE)
)

message("SDC-controlled monthly CSV and PNG have been created.")