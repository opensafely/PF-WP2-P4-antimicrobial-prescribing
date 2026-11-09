
# ------------------------------------------------------------------------------
# PRACTICE-LEVEL PRESCRIBING RATE ANALYSIS
#
# Graph A:
#   Monthly median (solid line), mean (dashed line), and IQR (shaded area)
#   across GP practices.
#
# Graph B:
#   Monthly relative variation = IQR / median.
#
# Year 1: February 2024 to January 2025
# Year 2: February 2025 to January 2026
#
# Annual rate:
#   Sum of annual monthly numerators /
#   Mean monthly denominator * 1,000
#
# Monthly eligibility:
#   - Raw monthly denominator >= min_denom.
#   - Numerator and denominator must not be suppressed by SDC.
#   - At least min_practices contributing practices for monthly summaries.
#
# Annual eligibility:
#   - 12 distinct months.
#   - 12 complete numerator and denominator observations.
#   - Raw mean monthly denominator >= min_denom.
#   - Annual numerator and mean denominator must not be suppressed.
#   - Practices must be eligible in BOTH years for annual comparisons.
#
# Statistical disclosure control:
#   - Zero counts retained as zero.
#   - Counts 1-7 suppressed and displayed as "Redacted" in CSV files.
#   - Counts >=8 rounded to nearest 5.
#   - SDC applied before calculating rates.
#   - Numeric NA values used internally for suppressed counts.
#   - CSV count columns converted to character.
#   - No practice-level CSV exported.
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

min_denom <- 10
min_practices <- 10

# Pharmacy First launch
PF_start <- as.Date("2024-02-01")

# Year boundaries
year1_start <- as.Date("2024-02-01")
year2_start <- as.Date("2025-02-01")
year2_end <- as.Date("2026-02-01")  # Exclusive upper bound

# GP Connect introduction
GP_connect <- as.Date("2025-10-01")

# Input data coverage
data_start <- as.Date("2022-02-01")
data_end <- as.Date("2026-02-01")   # Exclusive upper bound

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

# Numeric SDC function:
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


# Export SDC function:
# Converts suppressed or missing values to "Redacted".
# Output is character because it contains both numbers and text.

apply_sdc_export <- function(x) {

  case_when(
    is.na(x) ~ "Redacted",
    x == 0 ~ "0",
    x > 0 & x < 8 ~ "Redacted",
    TRUE ~ as.character(
      floor(x / 5 + 0.5) * 5
    )
  )
}


# Safe sum:
# Avoids returning zero when all observations are missing.

safe_sum <- function(x) {

  if (all(is.na(x))) {
    return(NA_real_)
  }

  sum(x, na.rm = TRUE)
}


# Safe mean

safe_mean <- function(x) {

  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}


# Safe quantile:
# Explicitly calls stats::quantile() to avoid recursive function calls.

safe_quantile <- function(x, p) {

  if (all(is.na(x))) {
    return(NA_real_)
  }

  as.numeric(
    stats::quantile(
      x,
      probs = p,
      na.rm = TRUE,
      names = FALSE
    )
  )
}


# 4. Read and validate input data ---------------------------------------------

input_file <- here(
  "output",
  "measures_new_approach_consultation_and_medication.csv"
)

if (!file.exists(input_file)) {
  stop("Input file not found: ", input_file)
}


# Read input data first

raw_data <- read_csv(
  input_file,
  show_col_types = FALSE
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


# Validate dates

if (anyNA(raw_data$interval_start)) {

  stop(
    "Some interval_start values are missing or could not be converted to dates."
  )
}


# Validate counts

if (
  any(raw_data$numerator < 0, na.rm = TRUE) ||
  any(raw_data$denominator < 0, na.rm = TRUE)
) {

  stop(
    "Numerators and denominators must not be negative."
  )
}


if (
  anyNA(raw_data$numerator) ||
  anyNA(raw_data$denominator)
) {

  warning(
    "Missing numerator or denominator values found. ",
    "They will be handled during aggregation and eligibility checks."
  )
}


# Filter the analysis period

raw_data <- raw_data %>%

  filter(
    interval_start >= data_start,
    interval_start < data_end
  )


if (nrow(raw_data) == 0) {
  stop("No observations found within the specified analysis period.")
}


# Data coverage check

min_month <- min(raw_data$interval_start)

max_month <- max(raw_data$interval_start)

last_required_month <- as.Date("2026-01-01")

message(
  "Data coverage: ",
  min_month,
  " to ",
  max_month
)


if (min_month > year1_start) {

  warning(
    "Data start (",
    min_month,
    ") is after Year 1 start (",
    year1_start,
    ")."
  )
}


if (max_month < last_required_month) {

  warning(
    "Data end (",
    max_month,
    ") is before the last required month (",
    last_required_month,
    ")."
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

    # Apply SDC before calculating prescribing rates

    numerator_nearest5 = apply_sdc(numerator),

    denominator_nearest5 = apply_sdc(denominator),

    # Monthly prescribing rate per 1,000 eligible population

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
      c(
        "interval_start",
        "practice",
        "Setting",
        "condition"
      )
    ]
  )
)


message(
  "Practice-level observations: ",
  nrow(rates_practice)
)


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

    # Number of practices contributing valid prescribing rates

    n_practices = sum(
      !is.na(prescribing_rate_nearest5_derived)
    ),

    # Median

    median = safe_quantile(
      prescribing_rate_nearest5_derived,
      0.50
    ),

    # Mean

    mean = safe_mean(
      prescribing_rate_nearest5_derived
    ),

    # First quartile

    q1 = safe_quantile(
      prescribing_rate_nearest5_derived,
      0.25
    ),

    # Third quartile

    q3 = safe_quantile(
      prescribing_rate_nearest5_derived,
      0.75
    ),

    .groups = "drop"
  ) %>%

  mutate(

    # Suppress monthly summaries based on too few practices

    suppressed = n_practices < min_practices,

    across(
      c(
        median,
        mean,
        q1,
        q3
      ),
      ~ if_else(
        suppressed,
        NA_real_,
        .x
      )
    )
  )


# Count suppressed monthly summaries

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

    n_practices_nearest5 = apply_sdc_export(
      n_practices
    )
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

      interval_start >= year1_start &
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

    # Number of distinct months with observations

    n_months = n_distinct(interval_start),

    # Number of months with both numerator and denominator available

    n_valid_months = sum(
      !is.na(numerator) &
        !is.na(denominator)
    ),

    # Mean monthly denominator

    mean_denominator = safe_mean(
      denominator
    ),

    # Aggregate raw monthly numerators before applying SDC

    annual_numerator = safe_sum(
      numerator
    ),

    .groups = "drop"
  ) %>%

  mutate(

    # Apply SDC to aggregated annual numerator

    annual_numerator_nearest5 = apply_sdc(
      annual_numerator
    ),

    # Apply SDC to mean monthly denominator

    mean_denominator_nearest5 = apply_sdc(
      mean_denominator
    ),

    # Annual rate per 1,000 average monthly eligible population

    annual_rate = if_else(

      n_months == 12 &
        n_valid_months == 12 &
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

    # Practices with at least one observation

    practices_with_data = n_distinct(practice),

    # Practices with 12 distinct months

    practices_with_12_months = n_distinct(
      practice[n_months == 12]
    ),

    # Practices with 12 complete months

    practices_with_12_complete_months = n_distinct(
      practice[
        n_months == 12 &
          n_valid_months == 12
      ]
    ),

    # Practices with eligible raw mean monthly denominator

    practices_with_mean_denominator_eligible = n_distinct(
      practice[
        !is.na(mean_denominator) &
          mean_denominator >= min_denom
      ]
    ),

    # Practices meeting both completeness and denominator criteria

    practices_meeting_both_criteria = n_distinct(
      practice[
        n_months == 12 &
          n_valid_months == 12 &
          !is.na(mean_denominator) &
          mean_denominator >= min_denom
      ]
    ),

    # Practices with a releasable annual rate after SDC

    practices_with_releasable_annual_rate = n_distinct(
      practice[
        !is.na(annual_rate)
      ]
    ),

    .groups = "drop"
  )


message(
  "\nAnnual eligibility diagnostics (unrounded, log only):"
)


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


# 10. Annual comparison: same practices in both years ------------------------

# Keep practice-years meeting all annual eligibility criteria

rates_practice_annual_eligible <- rates_practice_annual_all %>%

  filter(
    !is.na(annual_rate)
  )


# Identify practices eligible in BOTH years for each condition and setting

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

  filter(
    n_years == 2
  ) %>%

  select(
    practice,
    Setting,
    condition
  )


# Retain only practices eligible in both years

rates_practice_year <- rates_practice_annual_eligible %>%

  semi_join(
    eligible_practices_both_years,
    by = c(
      "practice",
      "Setting",
      "condition"
    )
  )


# 11. Aggregated annual summary -----------------------------------------------

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

    q1_annual_rate = safe_quantile(
      annual_rate,
      0.25
    ),

    q3_annual_rate = safe_quantile(
      annual_rate,
      0.75
    ),

    .groups = "drop"
  ) %>%

  mutate(

    # Suppress summaries based on too few practices

    suppressed = n_practices < min_practices,

    across(
      c(
        median_annual_rate,
        mean_annual_rate,
        q1_annual_rate,
        q3_annual_rate
      ),
      ~ if_else(
        suppressed,
        NA_real_,
        .x
      )
    ),

    # Apply SDC to the number of contributing practices

    n_practices_nearest5 = apply_sdc_export(
      n_practices
    )
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


# 12. Common plotting function ------------------------------------------------

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


# 13. Graph A: monthly prescribing trend --------------------------------------

plot_practice_trend <- function(cond, setting) {

  d <- rates_practice_summary %>%

    filter(
      condition == cond,
      Setting == setting
    )


  if (
    nrow(d) == 0 ||
      all(is.na(d$median))
  ) {

    return(
      empty_panel(
        paste0(
          "No releasable monthly summary data\n",
          cond,
          " / ",
          setting
        ),
        paste(
          "Monthly trend:",
          cond,
          "/",
          setting
        )
      )
    )
  }


  ggplot(
    d,
    aes(
      x = interval_start
    )
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

    expand_limits(
      y = 0
    ) +

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

      plot.subtitle = element_text(
        size = 9
      ),

      plot.title = element_text(
        face = "bold"
      ),

      panel.border = element_rect(
        colour = "#0085A1",
        fill = NA,
        linewidth = 0.7
      )
    )
}


# 14. Combine Graph A ----------------------------------------------------------

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


# 15. Generate monthly trend figures ------------------------------------------

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
    cond,
    " / ",
    setting
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


# 16. Graph B: monthly relative variation (IQR / median) -----------------------

plot_practice_iqr_median <- function(cond, setting) {

  d <- rates_practice_summary %>%

    filter(
      condition == cond,
      Setting == setting
    ) %>%

    mutate(

      # Relative variation = IQR / median

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
          cond,
          " / ",
          setting
        ),
        paste(
          "Monthly relative variation:",
          cond,
          "/",
          setting
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
        cond,
        " (",
        setting,
        ")"
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

      plot.subtitle = element_text(
        size = 9
      ),

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


# 17. Generate relative variation figures -------------------------------------

for (i in seq_len(nrow(practice_figs))) {

  cond <- practice_figs$condition[i]

  setting <- practice_figs$Setting[i]


  message(
    "Generating relative variation figure: ",
    cond,
    " / ",
    setting
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


# 18. Final quality checks -----------------------------------------------------

# Number of practices eligible in both years by condition and setting

practices_both_years_by_group <- rates_practice_year %>%

  group_by(
    Setting,
    condition
  ) %>%

  summarise(

    practices_with_both_years = n_distinct(practice),

    .groups = "drop"
  )


# Annual completeness check

annual_completeness_check <- rates_practice_annual_all %>%

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

    practices_with_12_complete_months = n_distinct(
      practice[
        n_months == 12 &
          n_valid_months == 12
      ]
    ),

    practices_with_eligible_annual_rate = n_distinct(
      practice[!is.na(annual_rate)]
    ),

    .groups = "drop"
  )


# Final console output

cat(
  "\n------------ QUALITY CHECKS --------------------------\n"
)


cat(
  "Data coverage: ",
  format(min_month),
  " to ",
  format(max_month),
  "\n"
)


cat(
  "Practice-month observations: ",
  nrow(rates_practice),
  "\n"
)


cat(
  "Distinct practices: ",
  n_distinct(rates_practice$practice),
  "\n"
)


cat(
  "Monthly summary rows: ",
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
  "Annual practice-year observations: ",
  nrow(rates_practice_annual_all),
  "\n"
)


cat(
  "Eligible practice-year rows: ",
  nrow(rates_practice_annual_eligible),
  "\n"
)


cat(
  "Practice-year rows retained for both-year comparison: ",
  nrow(rates_practice_year),
  "\n"
)


cat(
  "Distinct practices with both years (any setting/condition): ",
  n_distinct(rates_practice_year$practice),
  "\n"
)


cat(
  "Number of condition-setting figures: ",
  nrow(practice_figs),
  "\n"
)


cat(
  "\nPractices with both years, by setting and condition:\n"
)


print(
  practices_both_years_by_group,
  n = Inf
)


cat(
  "\nAnnual completeness check:\n"
)


print(
  annual_completeness_check,
  n = Inf
)


cat(
  "\nAnnual eligibility diagnostics (unrounded, log only):\n"
)


print(
  annual_diagnostics,
  n = Inf
)


cat(
  "\nAggregated output files saved in:\n"
)


cat(
  output_dir,
  "\n"
)
