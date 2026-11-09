
# ------------------------------------------------------------------------------
# PRACTICE-LEVEL PRESCRIBING RATE ANALYSIS
#
# Graph A:
#   Monthly median (solid line), mean (dashed line), and IQR (shaded area)
#   across GP practices.
#
# Additional graph:
#   Monthly relative variation = IQR / median.
#
# Year 1: February 2024 to January 2025
# Year 2: February 2025 to January 2026
#
# Annual rate:
#   Sum of monthly numerators / mean monthly denominator * 1,000
#
# Eligibility:
#   Monthly: raw monthly denominator >= min_denom, and numerator and
#   denominator must not be suppressed by SDC.
#   Annual: 12 months of data, raw mean monthly denominator >= min_denom,
#   and annual numerator and mean denominator must not be suppressed.
#
# Statistical disclosure control:
#   - Zero counts retained as zero.
#   - Counts 1-7 suppressed and displayed as "Redacted" in CSV files.
#   - Counts >=8 rounded to the nearest 5.
#   - SDC is applied to counts before calculating rates.
#   - Numeric NA values are used internally for suppressed counts.
#   - CSV count columns are converted to character so that "Redacted"
#     is displayed explicitly.
#   - No practice-level CSV is exported.
# ------------------------------------------------------------------------------


# 1. Packages -----------------------------------------------------------------

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(purrr)
library(here)
library(patchwork)


# 2. Settings -----------------------------------------------------------------

practice_var <- "practice"

min_denom <- 10     #1      #
min_practices <-10   # 1    #  minimum contributing practices for a monthly summary

# Pharmacy First launch
PF_start <- as.Date("2024-02-01")

# Year boundaries
year2_start <- as.Date("2025-02-01")
year2_end <- as.Date("2026-02-01")  # exclusive upper bound

# GP Connect introduction
GP_connect <- as.Date("2025-10-01")

# Condition identifiers used in the input measure names
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

# Output directory
output_dir <- here("output", "practice_level_change")

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)


# 3. Statistical disclosure control ------------------------------------------

# Numeric SDC function for calculations:
#   0       = 0
#   1-7     = NA (suppressed)
#   >=8     = rounded to nearest 5
#   NA      = NA
#
# Rounding uses half-up rounding.

apply_sdc <- function(x) {

  case_when(
    is.na(x) ~ NA_real_,
    x == 0 ~ 0,
    x > 0 & x < 8 ~ NA_real_,
    TRUE ~ floor(x / 5 + 0.5) * 5
  )
}


# Export function:
# Converts suppressed values to the explicit label "Redacted".
# The output is character because it contains both numbers and text.

apply_sdc_export <- function(x) {

  case_when(
    is.na(x) ~ "Redacted",
    x == 0 ~ "0",
    x > 0 & x < 8 ~ "Redacted",
    TRUE ~ as.character(floor(x / 5 + 0.5) * 5)
  )
}


# Safe sum: avoids returning zero when all observations are missing.

safe_sum <- function(x) {

  if (all(is.na(x))) {
    NA_real_
  } else {
    sum(x, na.rm = TRUE)
  }
}


# Quantile

quantile <- function(x, p) {

  if (all(is.na(x))) {
    NA_real_
  } else {
    as.numeric(quantile(x, p, na.rm = TRUE))
  }
}


# 4. Read and validate input data ---------------------------------------------

input_file <- here(
  "output",
  "measures_new_approach_consultation_and_medication.csv"
)

if (!file.exists(input_file)) {
  stop("Input file not found: ", input_file)
}

raw_data <- read_csv(
  input_file,
  show_col_types = FALSE
) %>%
  mutate(
    interval_start = as.Date(interval_start)
  ) %>%
  filter(
    interval_start >= as.Date("2022-02-01"),
    interval_start < as.Date("2026-02-01")
  )


# Required columns

required_columns <- c(
  "interval_start",
  "measure",
  practice_var,
  "numerator",
  "denominator"
)

missing_columns <- setdiff(
  required_columns,
  names(raw_data)
)

if (length(missing_columns) > 0) {
  stop(
    "Missing required columns: ",
    paste(missing_columns, collapse = ", ")
  )
}


# Standardise variables

raw_data <- raw_data %>%
  mutate(
    interval_start = as.Date(interval_start),
    practice = as.character(.data[[practice_var]]),
    numerator = as.numeric(numerator),
    denominator = as.numeric(denominator)
  )


if (anyNA(raw_data$interval_start)) {
  stop("Some interval_start values could not be converted to dates.")
}

if (
  any(raw_data$numerator < 0, na.rm = TRUE) ||
  any(raw_data$denominator < 0, na.rm = TRUE)
) {
  stop("Numerators and denominators must not be negative.")
}

if (
  anyNA(raw_data$numerator) ||
  anyNA(raw_data$denominator)
) {
  warning(
    "Missing numerator or denominator values found. ",
    "They will be handled during aggregation."
  )
}


# Data coverage check

min_month <- min(raw_data$interval_start)
max_month <- max(raw_data$interval_start)

last_required_month <- seq(
  year2_end,
  by = "-1 month",
  length.out = 2
)[2]

message("Data coverage: ", min_month, " to ", max_month)

if (min_month > PF_start) {
  warning(
    "Data start (", min_month, ") is after Year 1 start (",
    PF_start, ")."
  )
}

if (max_month < last_required_month) {
  warning(
    "Data end (", max_month, ") is before the last month of Year 2 (",
    last_required_month, ")."
  )
}


# 5. Select GP and Pharmacy First medication measures -------------------------

measure_pattern <- paste0(
  "^(gp|pf)_medication_(",
  paste(conditions, collapse = "|"),
  ")$"
)


rates_practice <- raw_data %>%

  filter(
    str_detect(measure, measure_pattern),
    !is.na(practice),
    practice != ""
  ) %>%

  extract(
    measure,
    into = c("setting_code", "condition_code"),
    regex = "^(gp|pf)_medication_(.*)$",
    remove = FALSE
  ) %>%

  mutate(
    Setting = recode(
      setting_code,
      gp = "GP",
      pf = "PF"
    ),

    condition = recode(
      condition_code,
      uti = "UTI",
      sinusitis = "Sinusitis",
      insectbite = "Insect bites",
      otitismedia = "Otitis media",
      sorethroat = "Sore throat",
      shingles = "Shingles",
      impetigo = "Impetigo",
      all_conditions = "All PF conditions",
      .default = condition_code
    )
  ) %>%

  group_by(
    interval_start,
    practice,
    Setting,
    condition
  ) %>%

  summarise(
    numerator = safe_sum(numerator),
    denominator = safe_sum(denominator),
    .groups = "drop"
  ) %>%

  mutate(

    # Apply SDC before calculating the prescribing rate
    numerator_nearest5 = apply_sdc(numerator),
    denominator_nearest5 = apply_sdc(denominator),

    prescribing_rate_nearest5_derived = if_else(
      !is.na(numerator_nearest5) &
        !is.na(denominator_nearest5) &
        denominator >= min_denom &
        denominator_nearest5 > 0,

      1000 * numerator_nearest5 / denominator_nearest5,

      NA_real_
    )
  )


if (nrow(rates_practice) == 0) {
  stop(
    "No matching practice-level medication measures found. ",
    "Check the measure names and conditions vector."
  )
}


# Confirm unique practice-month-setting-condition combinations

stopifnot(
  !anyDuplicated(
    rates_practice[
      c("interval_start", "practice", "Setting", "condition")
    ]
  )
)


message("Practice-level observations: ", nrow(rates_practice))

message(
  "Distinct practices: ",
  n_distinct(rates_practice$practice)
)


# 6. Graph A data: monthly distribution across practices ----------------------

rates_practice_summary <- rates_practice %>%

  group_by(
    interval_start,
    Setting,
    condition
  ) %>%

  summarise(

    n_practices = sum(!is.na(prescribing_rate_nearest5_derived)),

    median = quantile(prescribing_rate_nearest5_derived, 0.50),

    mean = if (all(is.na(prescribing_rate_nearest5_derived))) {
      NA_real_
    } else {
      mean(prescribing_rate_nearest5_derived, na.rm = TRUE)
    },

     q1 =stats::quantile(prescribing_rate_nearest5_derived, probs = 0.25, na.rm = TRUE),#q1 = quantile(prescribing_rate_nearest5_derived, 0.25),

     q3 =stats::quantile(prescribing_rate_nearest5_derived, probs = 0.25, na.rm = TRUE),#q3 = quantile(prescribing_rate_nearest5_derived, 0.75),

    .groups = "drop"
  ) %>%

  mutate(

    # Suppress summaries based on too few contributing practices
    suppressed = n_practices < min_practices,

    across(
      c(median, mean, q1, q3),
      ~ if_else(suppressed, NA_real_, .x)
    )
  )


n_suppressed_months <- sum(
  rates_practice_summary$suppressed
)

if (n_suppressed_months > 0) {

  message(
    "Monthly summaries suppressed (< ",
    min_practices,
    " practices): ",
    n_suppressed_months
  )
}


# 7. Export monthly summary ---------------------------------------------------

rates_practice_summary_release <- rates_practice_summary %>%

  mutate(
    n_practices_nearest5 = apply_sdc_export(n_practices)
  ) %>%

  select(
    interval_start,
    Setting,
    condition,
    n_practices_nearest5,
    median,
    mean,
    q1,
    q3,
    suppressed
  )


write_csv(
  rates_practice_summary_release,
  file.path(
    output_dir,
    "practice_rate_monthly_summary.csv"
  )
)


# 8. Annual data and aggregated annual summary -------------------------------

rates_practice_annual_all <- rates_practice %>%

  mutate(
    year = case_when(

      interval_start >= PF_start &
        interval_start < year2_start ~ "Year 1",

      interval_start >= year2_start &
        interval_start < year2_end ~ "Year 2",

      TRUE ~ NA_character_
    )
  ) %>%

  filter(!is.na(year)) %>%

  group_by(
    practice,
    Setting,
    condition,
    year
  ) %>%

  summarise(

    n_months = n_distinct(interval_start),

    mean_denominator = if (all(is.na(denominator))) {
      NA_real_
    } else {
      mean(denominator, na.rm = TRUE)
    },

    annual_numerator = safe_sum(numerator),

    .groups = "drop"
  ) %>%

  mutate(

    # Aggregate raw monthly counts first, then apply SDC
    annual_numerator_nearest5 = apply_sdc(annual_numerator),

    mean_denominator_nearest5 = apply_sdc(mean_denominator),

    annual_rate = if_else(

      n_months == 12 &
        mean_denominator >= min_denom &
        !is.na(annual_numerator_nearest5) &
        !is.na(mean_denominator_nearest5) &
        mean_denominator_nearest5 > 0,

      1000 * annual_numerator_nearest5 /
        mean_denominator_nearest5,

      NA_real_
    )
  )


# 9. Annual eligibility diagnostics -------------------------------------------

annual_diagnostics <- rates_practice_annual_all %>%

  group_by(
    Setting,
    condition,
    year
  ) %>%

  summarise(

    practices_with_data = n_distinct(practice),

    practices_with_12_months = n_distinct(
      practice[n_months == 12]
    ),

    practices_with_mean_denominator_eligible = n_distinct(
      practice[
        !is.na(mean_denominator) &
          mean_denominator >= min_denom
      ]
    ),

    practices_meeting_both_criteria = n_distinct(
      practice[
        n_months == 12 &
          !is.na(mean_denominator) &
          mean_denominator >= min_denom
      ]
    ),

    .groups = "drop"
  )


message("\nAnnual eligibility diagnostics (unrounded, log only):")

print(
  annual_diagnostics,
  n = Inf
)


# Export diagnostics with nearest-5 SDC

annual_diagnostics_release <- annual_diagnostics %>%

  mutate(
    across(
      starts_with("practices_"),
      apply_sdc_export
    )
  ) %>%

  rename_with(
    ~ paste0(.x, "_nearest5"),
    starts_with("practices_")
  )


write_csv(
  annual_diagnostics_release,
  file.path(
    output_dir,
    "practice_rate_annual_diagnostics.csv"
  )
)


# 10. Aggregated annual summary -----------------------------------------------

# Keep practice-years that meet the annual eligibility criteria

rates_practice_annual_eligible <- rates_practice_annual_all %>%

  filter(!is.na(annual_rate))


# Keep practices with eligible data in BOTH years

eligible_practices_both_years <- rates_practice_annual_eligible %>%

  group_by(
    practice,
    Setting,
    condition
  ) %>%

  summarise(
    n_years = n_distinct(year),
    .groups = "drop"
  ) %>%

  filter(n_years == 2) %>%

  select(
    practice,
    Setting,
    condition
  )


rates_practice_year <- rates_practice_annual_eligible %>%

  semi_join(
    eligible_practices_both_years,
    by = c("practice", "Setting", "condition")
  )


# Aggregated annual summary only.
# No practice-level CSV is exported.

annual_summary <- rates_practice_year %>%

  group_by(
    Setting,
    condition,
    year
  ) %>%

  summarise(

    n_practices = n_distinct(practice),

    median_annual_rate = median(
      annual_rate,
      na.rm = TRUE
    ),

    mean_annual_rate = mean(
      annual_rate,
      na.rm = TRUE
    ),

    q1_annual_rate = as.numeric(
      stats::quantile(annual_rate, probs = 0.25, na.rm = TRUE) #quantile(annual_rate, 0.25, na.rm = TRUE)
    ),

    q3_annual_rate = as.numeric(
      stats::quantile(annual_rate, probs = 0.75, na.rm = TRUE) #quantile(annual_rate, 0.75, na.rm = TRUE)
    ),

    .groups = "drop"
  ) %>%

  mutate(

    suppressed = n_practices < min_practices,

    across(
      c(
        median_annual_rate,
        mean_annual_rate,
        q1_annual_rate,
        q3_annual_rate
      ),
      ~ if_else(suppressed, NA_real_, .x)
    ),

    n_practices_nearest5 = apply_sdc_export(n_practices)
  ) %>%

  select(
    Setting,
    condition,
    year,
    n_practices_nearest5,
    median_annual_rate,
    mean_annual_rate,
    q1_annual_rate,
    q3_annual_rate,
    suppressed
  )


write_csv(
  annual_summary,
  file.path(
    output_dir,
    "practice_rate_annual_summary.csv"
  )
)


# 11. Common plotting function ------------------------------------------------

empty_panel <- function(label, title) {

  ggplot() +

    annotate(
      "text",
      x = 1,
      y = 1,
      label = label,
      size = 3.5
    ) +

    xlim(0, 2) +

    ylim(0, 2) +

    labs(
      title = title,
      x = NULL,
      y = NULL
    ) +

    theme_void()
}


# 12. Graph A: monthly prescribing trend --------------------------------------

plot_practice_trend <- function(cond, setting) {

  d <- rates_practice_summary %>%

    filter(
      condition == cond,
      Setting == setting
    )


  if (nrow(d) == 0 || all(is.na(d$median))) {

    return(
      empty_panel(
        paste0(
          "No releasable monthly summary data\n",
          cond, " / ", setting
        ),
        paste("Monthly trend:", cond, "/", setting)
      )
    )
  }


  ggplot(
    d,
    aes(x = interval_start)
  ) +

    # IQR ribbon
    geom_ribbon(
      aes(
        ymin = q1,
        ymax = q3
      ),
      fill = "#80BDC9",
      alpha = 0.5,
      na.rm = TRUE
    ) +

    # Median
    geom_line(
      aes(
        y = median,
        colour = "Median",
        linetype = "Median"
      ),
      linewidth = 0.7,
      na.rm = TRUE
    ) +

    # Mean
    geom_line(
      aes(
        y = mean,
        colour = "Mean",
        linetype = "Mean"
      ),
      linewidth = 0.7,
      na.rm = TRUE
    ) +

    # Pharmacy First launch
    geom_vline(
      xintercept = PF_start,
      linetype = "dashed",
      linewidth = 0.2,
      colour = "blue"
    ) +

    # GP Connect introduction
    geom_vline(
      xintercept = GP_connect,
      linetype = "dashed",
      linewidth = 0.2,
      colour = "black"
    ) +

    scale_colour_manual(
      values = c(
        Median = "black",
        Mean = "#C0392B"
      ),
      name = NULL
    ) +

    scale_linetype_manual(
      values = c(
        Median = "solid",
        Mean = "dashed"
      ),
      name = NULL
    ) +

    scale_x_date(
      date_labels = "%Y-%m",
      date_breaks = "2 months",
      expand = expansion(
        mult = c(0.01, 0.02)
      )
    ) +

    scale_y_continuous(
      expand = expansion(
        mult = c(0, 0.05)
      )
    ) +

    expand_limits(y = 0) +

    labs(

      subtitle = paste(
        "Median (solid), mean (dashed);",
        "shaded area = IQR"
      ),

      x = "Month",

      y = "Prescribing rate per 1,000 eligible population"
    ) +

    theme_bw() +

    theme(

      legend.position = "bottom",

      axis.text.x = element_text(
        angle = 45,
        hjust = 1
      ),

      plot.subtitle = element_text(size = 9),

      plot.title = element_text(face = "bold"),

      panel.border = element_rect(
        colour = "#0085A1",
        fill = NA,
        linewidth = 0.7
      )
    )
}


# 13. Combine Graph A ----------------------------------------------------------

plot_practice_figure <- function(cond, setting) {

  p1 <- plot_practice_trend(
    cond,
    setting
  )

  p1 +

    plot_annotation(

      title = paste0(
        "Prescribing rates by general practice for ",
        cond,
        ": ",
        setting
      ),

      caption = paste0(
        "Blue dashed line = Pharmacy First launch; ",
        "black dashed line = GP Connect introduction.\n",
        "Statistical disclosure control: counts 1-7 redacted; ",
        "remaining positive counts rounded to nearest 5; ",
        "zero counts retained."
      ),

      theme = theme(

        plot.title = element_text(
          face = "bold",
          size = 14
        ),

        plot.caption = element_text(
          size = 8,
          hjust = 0
        )
      )
    ) +

    theme(

      panel.background = element_rect(
        fill = "white",
        colour = NA
      ),

      panel.border = element_rect(
        fill = NA,
        colour = "black",
        linewidth = 0.4
      ),

      panel.grid.major = element_line(
        colour = "grey85",
        linetype = "dashed",
        linewidth = 0.3
      ),

      panel.grid.minor = element_blank(),

      plot.background = element_rect(
        fill = "white",
        colour = NA
      ),

      legend.key = element_rect(
        fill = "white",
        colour = NA
      ),

      strip.background = element_rect(
        fill = "#037A92",
        colour = "#037A92"
      ),

      strip.text = element_text(
        colour = "white",
        face = "bold"
      ),

      legend.position = "bottom",

      axis.text.x = element_text(
        angle = 45,
        hjust = 1
      )
    )
}


# 14. Generate monthly trend figures ------------------------------------------

practice_figs <- rates_practice %>%

  distinct(
    condition,
    Setting
  ) %>%

  arrange(
    condition,
    Setting
  )


for (i in seq_len(nrow(practice_figs))) {

  cond <- practice_figs$condition[i]

  setting <- practice_figs$Setting[i]

  message(
    "Generating monthly trend figure: ",
    cond, " / ", setting
  )

  p <- plot_practice_figure(
    cond,
    setting
  )

  file_stub <- str_replace_all(
    tolower(cond),
    "[^a-z0-9]+",
    "_"
  )

  output_file <- file.path(
    output_dir,
    paste0(
      "practice_rate_",
      tolower(setting),
      "_",
      file_stub,
      ".png"
    )
  )

  ggsave(
    filename = output_file,
    plot = p,
    width = 12,
    height = 5.5,
    units = "in",
    dpi = 300,
    bg = "white"
  )
}


# 15. Graph: monthly relative variation (IQR / median) ------------------------

plot_practice_iqr_median <- function(cond, setting) {

  d <- rates_practice_summary %>%

    filter(
      condition == cond,
      Setting == setting
    ) %>%

    mutate(

      relative_variation = if_else(

        !is.na(median) &
          median > 0 &
          !is.na(q1) &
          !is.na(q3),

        (q3 - q1) / median,

        NA_real_
      )
    )


  if (
    nrow(d) == 0 ||
      all(is.na(d$relative_variation))
  ) {

    return(
      empty_panel(
        paste0(
          "No releasable monthly variation data\n",
          cond, " / ", setting
        ),
        paste(
          "Monthly relative variation:",
          cond, "/", setting
        )
      )
    )
  }


  ggplot(
    d,
    aes(
      x = interval_start,
      y = relative_variation
    )
  ) +

    # Relative variation (IQR / median)
    geom_line(
      colour = "#0085A1",
      linewidth = 0.8,
      na.rm = TRUE
    ) +

    # Pharmacy First launch
    geom_vline(
      xintercept = PF_start,
      linetype = "dashed",
      linewidth = 0.3,
      colour = "blue"
    ) +

    # GP Connect introduction
    geom_vline(
      xintercept = GP_connect,
      linetype = "dashed",
      linewidth = 0.3,
      colour = "grey40"
    ) +

    scale_x_date(
      date_labels = "%Y-%m",
      date_breaks = "2 months",
      expand = expansion(
        mult = c(0.01, 0.02)
      )
    ) +

    scale_y_continuous(
      labels = scales::label_percent(),
      expand = expansion(
        mult = c(0, 0.05)
      )
    ) +

    labs(

      title = paste0(
        "Monthly relative variation in prescribing rates: ",
        cond, " (", setting, ")"
      ),

      subtitle = paste(
        "Relative variation = interquartile range (IQR) / median"
      ),

      x = "Month",

      y = "Relative variation (IQR / median)",

      caption = paste(
        "Blue dashed line: Pharmacy First launch;",
        "grey dashed line: GP Connect introduction."
      )
    ) +

    theme_bw() +

    theme(

      plot.title = element_text(
        face = "bold",
        size = 13
      ),

      plot.subtitle = element_text(size = 9),

      plot.caption = element_text(
        size = 8,
        hjust = 0
      ),

      panel.border = element_rect(
        colour = "#0085A1",
        fill = NA,
        linewidth = 0.7
      ),

      panel.grid.major = element_line(
        colour = "grey85",
        linetype = "dashed",
        linewidth = 0.3
      ),

      panel.grid.minor = element_blank(),

      axis.text.x = element_text(
        angle = 45,
        hjust = 1
      )
    )
}


# 16. Generate relative variation figures -------------------------------------

for (i in seq_len(nrow(practice_figs))) {

  cond <- practice_figs$condition[i]

  setting <- practice_figs$Setting[i]

  message(
    "Generating median/IQR figure: ",
    cond, " / ", setting
  )

  p <- plot_practice_iqr_median(
    cond,
    setting
  )

  file_stub <- str_replace_all(
    tolower(cond),
    "[^a-z0-9]+",
    "_"
  )

  output_file <- file.path(
    output_dir,
    paste0(
      "practice_rate_iqr_median_",
      tolower(setting),
      "_",
      file_stub,
      ".png"
    )
  )

  ggsave(
    filename = output_file,
    plot = p,
    width = 12,
    height = 5.5,
    units = "in",
    dpi = 300,
    bg = "white"
  )
}


# 17. Final quality checks -----------------------------------------------------

practices_both_years_by_group <- rates_practice_year %>%

  group_by(
    Setting,
    condition
  ) %>%

  summarise(
    practices_with_both_years = n_distinct(practice),
    .groups = "drop"
  )


cat("\n------------ QUALITY CHECKS --------------------------\n")

cat(
  "Data coverage:",
  format(min_month),
  "to",
  format(max_month),
  "\n"
)

cat(
  "Practice-month observations:",
  nrow(rates_practice),
  "\n"
)

cat(
  "Distinct practices:",
  n_distinct(rates_practice$practice),
  "\n"
)

cat(
  "Monthly summary rows:",
  nrow(rates_practice_summary),
  "\n"
)

cat(
  "Monthly summaries suppressed (< ",
  min_practices,
  " practices): ",
  n_suppressed_months,
  "\n"
)

cat(
  "Eligible practice-year rows:",
  nrow(rates_practice_annual_eligible),
  "\n"
)

cat(
  "Distinct practices with both years (any setting/condition):",
  n_distinct(rates_practice_year$practice),
  "\n"
)

cat(
  "Number of condition-setting figures:",
  nrow(practice_figs),
  "\n"
)

cat("\nPractices with both years, by setting and condition:\n")

print(
  practices_both_years_by_group,
  n = Inf
)

cat("\nAggregated output files saved in:\n")

cat(
  output_dir,
  "\n"
)

cat("\nAnnual eligibility diagnostics (unrounded, log only):\n")

print(
  annual_diagnostics,
  n = Inf
)
