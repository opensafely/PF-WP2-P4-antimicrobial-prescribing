
# ------------------------------------------------------------------------------
# PRACTICE-LEVEL PHARMACY FIRST PRESCRIBING ANALYSIS
#
# Graph A:
#   Monthly median (solid line), mean (dashed line), and IQR (shaded area)
#   across GP practices.
#
# Graph B:
#   Year 1 versus Year 2 annual prescribing rates for each practice.
#
# Year 1: February 2024 to January 2025
# Year 2: February 2025 to January 2026
#
# Annual rate:
#   Sum of monthly numerators / mean monthly denominator * 1,000
#
# Monthly Graph A rates require denominator >= 100.
# Annual comparisons require 12 months in each year and mean monthly
# denominator >= 100.
#
# Detailed practice-level CSVs are not written to output by default,
# to avoid exceeding OpenSAFELY output-release row limits.
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
min_denom <- 100

PF_start <- as.Date("2024-02-01")
year2_start <- as.Date("2025-02-01")
year2_end <- as.Date("2026-02-01")

# Pharmacy First launch and GP Connect introduction
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
output_dir <- here("output")

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# 3. Read and validate input data ---------------------------------------------

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
)

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

if (any(raw_data$numerator < 0, na.rm = TRUE) ||
    any(raw_data$denominator < 0, na.rm = TRUE)) {
  stop("Numerators and denominators must not be negative.")
}

if (anyNA(raw_data$numerator) || anyNA(raw_data$denominator)) {
  warning(
    "Missing numerator or denominator values found. ",
    "They will be handled during aggregation."
  )
}

# 4. Select GP and Pharmacy First medication measures -------------------------

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
    numerator = sum(numerator, na.rm = TRUE),
    denominator = sum(denominator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    prescribing_rate = if_else(
      denominator >= min_denom,
      1000 * numerator / denominator,
      NA_real_
    )
  )

if (nrow(rates_practice) == 0) {
  stop(
    "No matching practice-level medication measures found. ",
    "Check the measure names and conditions vector."
  )
}

# Confirm that each practice-month-setting-condition combination is unique.
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

# 5. Graph A data: monthly distribution across practices ----------------------

rates_practice_summary <- rates_practice %>%
  group_by(interval_start, Setting, condition) %>%
  summarise(
    n_practices = sum(!is.na(prescribing_rate)),

    median = if (all(is.na(prescribing_rate))) {
      NA_real_
    } else {
      median(prescribing_rate, na.rm = TRUE)
    },

    mean = if (all(is.na(prescribing_rate))) {
      NA_real_
    } else {
      mean(prescribing_rate, na.rm = TRUE)
    },

    q1 = if (all(is.na(prescribing_rate))) {
      NA_real_
    } else {
      as.numeric(
        quantile(
          prescribing_rate,
          probs = 0.25,
          na.rm = TRUE
        )
      )
    },

    q3 = if (all(is.na(prescribing_rate))) {
      NA_real_
    } else {
      as.numeric(
        quantile(
          prescribing_rate,
          probs = 0.75,
          na.rm = TRUE
        )
      )
    },

    .groups = "drop"
  )

# Aggregated output: suitable for release review, subject to normal checks.
write_csv(
  rates_practice_summary,
  here("output", "practice_rate_monthly_summary.csv")
)

# 6. Graph B data: annual rates per practice ----------------------------------

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
  group_by(practice, Setting, condition, year) %>%
  summarise(
    n_months = n_distinct(interval_start),

    mean_denominator = mean(
      denominator,
      na.rm = TRUE
    ),

    annual_numerator = sum(
      numerator,
      na.rm = TRUE
    ),

    annual_rate = if (
      n_distinct(interval_start) == 12 &&
      mean(denominator, na.rm = TRUE) >= min_denom
    ) {
      1000 * sum(numerator, na.rm = TRUE) /
        mean(denominator, na.rm = TRUE)
    } else {
      NA_real_
    },

    .groups = "drop"
  )

# Diagnostic table: inspect missing months and denominator eligibility.
annual_diagnostics <- rates_practice_annual_all %>%
  group_by(Setting, condition, year) %>%
  summarise(
    practices_with_data = n_distinct(practice),

    practices_with_12_months = n_distinct(
      practice[n_months == 12]
    ),

    practices_with_mean_denominator_100_or_more = n_distinct(
      practice[mean_denominator >= min_denom]
    ),

    practices_meeting_both_criteria = n_distinct(
      practice[
        n_months == 12 &
          mean_denominator >= min_denom
      ]
    ),

    .groups = "drop"
  )

message("\nAnnual eligibility diagnostics:")
print(annual_diagnostics, n = Inf)

# Save aggregated diagnostics rather than practice-level records.
write_csv(
  annual_diagnostics,
  here("output", "practice_rate_annual_diagnostics.csv")
)

# Keep only practice-years that meet the annual eligibility criteria.
rates_practice_annual_eligible <- rates_practice_annual_all %>%
  filter(
    n_months == 12,
    mean_denominator >= min_denom,
    !is.na(annual_rate)
  )

# Keep only practices with eligible data in BOTH years.
eligible_practices_both_years <- rates_practice_annual_eligible %>%
  group_by(practice, Setting, condition) %>%
  summarise(
    n_years = n_distinct(year),
    .groups = "drop"
  ) %>%
  filter(n_years == 2) %>%
  select(practice, Setting, condition)

rates_practice_year <- rates_practice_annual_eligible %>%
  semi_join(
    eligible_practices_both_years,
    by = c("practice", "Setting", "condition")
  )

# Save an aggregated annual summary only; do not export practice-level rows.
annual_summary <- rates_practice_year %>%
  group_by(Setting, condition, year) %>%
  summarise(
    n_practices = n_distinct(practice),
    median_annual_rate = median(annual_rate, na.rm = TRUE),
    mean_annual_rate = mean(annual_rate, na.rm = TRUE),
    q1_annual_rate = as.numeric(
      quantile(annual_rate, 0.25, na.rm = TRUE)
    ),
    q3_annual_rate = as.numeric(
      quantile(annual_rate, 0.75, na.rm = TRUE)
    ),
    .groups = "drop"
  )

write_csv(
  annual_summary,
  here("output", "practice_rate_annual_summary.csv")
)

# 7. Graph A: monthly prescribing trend ---------------------------------------

plot_practice_trend <- function(cond, setting) {

  d <- rates_practice_summary %>%
    filter(
      condition == cond,
      Setting == setting
    )

  if (nrow(d) == 0) {
    return(
      ggplot() +
        annotate(
          "text",
          x = 1,
          y = 1,
          label = paste0(
            "No monthly summary data\n",
            cond, " / ", setting
          )
        ) +
        xlim(0, 2) +
        ylim(0, 2) +
        labs(
          title = paste("Monthly trend:", cond, "/", setting),
          x = NULL,
          y = NULL
        ) +
        theme_void()
    )
  }

  ggplot(d, aes(x = interval_start)) +

    geom_ribbon(
      aes(ymin = q1, ymax = q3),
      fill = "#9FB3C8",
      alpha = 0.5,
      na.rm = TRUE
    ) +

    geom_line(
      aes(y = median, colour = "Median", linetype = "Median"),
      linewidth = 0.7,
      na.rm = TRUE
    ) +

    geom_line(
      aes(y = mean, colour = "Mean", linetype = "Mean"),
      linewidth = 0.7,
      na.rm = TRUE
    ) +

    geom_vline(
      xintercept = PF_start,
      linetype = "dashed",
      linewidth = 0.5,
      colour = "blue"
    ) +

    geom_vline(
      xintercept = GP_connect,
      linetype = "dashed",
      linewidth = 0.5,
      colour = "black"
    ) +

    scale_colour_manual(
      values = c(
        Median = "#2C4A6E",
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
      expand = expansion(mult = c(0.01, 0.02))
    ) +

    scale_y_continuous(
      expand = expansion(mult = c(0, 0.05))
    ) +

    labs(
      title = paste0(
        "Monthly ", setting, " prescribing across GP practices"
      ),
      subtitle = paste(
        "Median (solid), mean (dashed);",
        "shaded area = interquartile range"
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
      plot.title = element_text(face = "bold")
    )
}

# 8. Graph B: Year 1 versus Year 2 --------------------------------------------

plot_practice_change <- function(cond, setting) {

  d <- rates_practice_year %>%
    filter(
      condition == cond,
      Setting == setting
    )

  # If no practices qualify, show a panel rather than stopping the script.
  if (nrow(d) == 0) {
    return(
      ggplot() +
        annotate(
          "text",
          x = 1,
          y = 1,
          label = paste0(
            "No complete annual comparisons\n",
            cond, " / ", setting,
            "\nCheck annual eligibility diagnostics"
          ),
          size = 3.5
        ) +
        xlim(0, 2) +
        ylim(0, 2) +
        labs(
          title = "Change across GP practices",
          x = NULL,
          y = NULL
        ) +
        theme_void()
    )
  }

  wide <- d %>%
    select(practice, year, annual_rate) %>%
    pivot_wider(
      names_from = year,
      values_from = annual_rate
    )

  # Guard against missing year columns.
  if (!"Year 1" %in% names(wide)) {
    wide[["Year 1"]] <- NA_real_
  }

  if (!"Year 2" %in% names(wide)) {
    wide[["Year 2"]] <- NA_real_
  }

  wide <- wide %>%
    filter(
      !is.na(`Year 1`),
      !is.na(`Year 2`)
    )

  if (nrow(wide) == 0) {
    return(
      ggplot() +
        annotate(
          "text",
          x = 1,
          y = 1,
          label = paste0(
            "No practices have both years\n",
            cond, " / ", setting
          ),
          size = 3.5
        ) +
        xlim(0, 2) +
        ylim(0, 2) +
        labs(
          title = "Change across GP practices",
          x = NULL,
          y = NULL
        ) +
        theme_void()
    )
  }

  n_up <- sum(wide$`Year 2` > wide$`Year 1`)
  n_down <- sum(wide$`Year 2` < wide$`Year 1`)
  n_same <- sum(wide$`Year 2` == wide$`Year 1`)
  n_tot <- nrow(wide)

  lab <- paste0(
    "Practices: ", n_tot,
    "\nIncreased: ", n_up,
    " | Decreased: ", n_down,
    " | Unchanged: ", n_same
  )

  d_plot <- d %>%
    filter(practice %in% wide$practice) %>%
    mutate(
      year = factor(
        year,
        levels = c("Year 1", "Year 2")
      )
    )

  ggplot(
    d_plot,
    aes(
      x = year,
      y = annual_rate,
      group = practice
    )
  ) +

    geom_line(
      colour = "grey65",
      alpha = 0.3,
      linewidth = 0.25
    ) +

    geom_point(
      data = filter(d_plot, year == "Year 1"),
      colour = "#3B6FB6",
      size = 1.1,
      alpha = 0.65
    ) +

    geom_point(
      data = filter(d_plot, year == "Year 2"),
      colour = "#E67E22",
      shape = 17,
      size = 1.2,
      alpha = 0.65
    ) +

    annotate(
      "label",
      x = 1.5,
      y = Inf,
      label = lab,
      vjust = 1.15,
      size = 2.8,
      label.size = 0.2,
      fill = "grey95"
    ) +

    scale_y_continuous(
      expand = expansion(mult = c(0.02, 0.18))
    ) +

    labs(
      title = "Change across GP practices",
      subtitle = "Blue circle = Year 1; orange triangle = Year 2",
      x = NULL,
      y = "Annual prescribing rate per 1,000 average eligible population"
    ) +

    theme_bw() +

    theme(
      plot.subtitle = element_text(size = 9),
      plot.title = element_text(face = "bold"),
      axis.text.x = element_text(size = 10)
    )
}

# 9. Combine Graphs A and B ----------------------------------------------------

plot_practice_figure <- function(cond, setting) {

  p1 <- plot_practice_trend(cond, setting)
  p2 <- plot_practice_change(cond, setting)

  p1 + p2 +
    plot_layout(widths = c(2.4, 1)) +
    plot_annotation(
      title = paste0(
        cond, ": ", setting,
        " prescribing rates by GP practice"
      ),
      caption = paste0(
        "Year 1 = Feb 2024 to Jan 2025; ",
        "Year 2 = Feb 2025 to Jan 2026. ",
        "Blue dashed line = Pharmacy First launch; ",
        "black dashed line = GP Connect introduction. ",
        "Annual comparisons require 12 months in each year ",
        "and mean monthly denominator >= ", min_denom, "."
      ),
      theme = theme(
        plot.title = element_text(
          face = "bold",
          size = 14
        ),
        plot.caption = element_text(size = 8)
      )
    )
}

# 10. Generate figures ---------------------------------------------------------

practice_figs <- rates_practice %>%
  distinct(condition, Setting) %>%
  arrange(condition, Setting)

for (i in seq_len(nrow(practice_figs))) {

  cond <- practice_figs$condition[i]
  setting <- practice_figs$Setting[i]

  message(
    "Generating figure: ",
    cond, " / ", setting
  )

  p <- plot_practice_figure(cond, setting)

  file_stub <- str_replace_all(
    tolower(cond),
    "[^a-z0-9]+",
    "_"
  )

  output_file <- here(
    "output",
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

# 11. Final quality checks -----------------------------------------------------

cat("\n========== QUALITY CHECKS ==========\n")

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
  "Eligible practice-year rows:",
  nrow(rates_practice_annual_eligible),
  "\n"
)

cat(
  "Practices with both years:",
  nrow(rates_practice_year),
  "\n"
)

cat(
  "Number of condition-setting figures:",
  nrow(practice_figs),
  "\n"
)

cat("\nAggregated output files saved in:\n")
cat(output_dir, "\n")

cat("\nAnnual eligibility diagnostics:\n")
print(annual_diagnostics, n = Inf)
#
