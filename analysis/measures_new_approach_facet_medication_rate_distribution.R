
# -------------------------------------------------------------------------------------
# PRACTICE-LEVEL PHARMACY FIRST PRESCRIBING ANALYSIS
#
# Graph A: Monthly median (solid), mean (dashed), IQR (shaded)
# Graph B: Year 1 versus Year 2 annual prescribing rates by practice
#
# Year 1: February 2024 - January 2025
# Year 2: February 2025 - January 2026
#
# Annual rate = total prescriptions / mean monthly eligible population * 1000
# Minimum monthly denominator = 100
#---------------------------------------------------------------------------------------
# 1. Packages ---------------------------------------------------------------------------

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

# GP Connect introduction
GP_connect <- as.Date("2025-10-01")

# Conditions represented in the medication measure names.
# Edit this list if the input file uses different condition identifiers.
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
dir.create(
  here("output"),
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
    practice = as.character(.data[[practice_var]])
  )

if (anyNA(raw_data$interval_start)) {
  stop("Some interval_start values could not be converted to dates.")
}

if (any(raw_data$numerator < 0, na.rm = TRUE) ||
    any(raw_data$denominator < 0, na.rm = TRUE)) {
  stop("Numerators and denominators must not be negative.")
}

# 4. Extract GP and Pharmacy First medication measures ------------------------

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

# Check for duplicate practice-month-condition-setting combinations.
# These should not exist after the aggregation above.
stopifnot(
  !anyDuplicated(
    rates_practice[
      c("interval_start", "practice", "Setting", "condition")
    ]
  )
)

# Save practice-level monthly rates for reproducibility.
write_csv(
  rates_practice,
  here("output", "practice_rate_monthly_by_practice.csv")
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
        quantile(prescribing_rate, 0.25, na.rm = TRUE)
      )
    },

    q3 = if (all(is.na(prescribing_rate))) {
      NA_real_
    } else {
      as.numeric(
        quantile(prescribing_rate, 0.75, na.rm = TRUE)
      )
    },

    .groups = "drop"
  )

# Save Graph A data.
write_csv(
  rates_practice_summary,
  here("output", "practice_rate_monthly_summary.csv")
)

# 6. Graph B data: annual rate per practice -----------------------------------

rates_practice_year <- rates_practice %>%
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

    annual_rate = if (
      n_distinct(interval_start) == 12 &&
      all(denominator >= min_denom)
    ) {
      1000 * sum(numerator) / mean(denominator)
    } else {
      NA_real_
    },

    .groups = "drop"
  ) %>%
  mutate(
    year = factor(
      year,
      levels = c("Year 1", "Year 2")
    )
  ) %>%
  # Keep only complete 12-month periods with valid rates.
  filter(
    n_months == 12,
    !is.na(annual_rate)
  ) %>%
  group_by(practice, Setting, condition) %>%
  # Keep practices with both annual observations.
  filter(n_distinct(year) == 2) %>%
  ungroup()

# Save Graph B data.
write_csv(
  rates_practice_year %>%
    mutate(year = as.character(year)),
  here("output", "practice_rate_year1_year2.csv")
)

# 7. Graph A: monthly prescribing trend ---------------------------------------

plot_practice_trend <- function(cond, setting) {

  d <- rates_practice_summary %>%
    filter(
      condition == cond,
      Setting == setting
    )

  if (nrow(d) == 0) {
    stop("No monthly summary data for: ", cond, " / ", setting)
  }

  ggplot(d, aes(x = interval_start)) +

    # Interquartile range across practices
    geom_ribbon(
      aes(ymin = q1, ymax = q3),
      fill = "#9FB3C8",
      alpha = 0.5,
      na.rm = TRUE
    ) +

    # Median: solid line
    geom_line(
      aes(y = median, colour = "Median", linetype = "Median"),
      linewidth = 0.7,
      na.rm = TRUE
    ) +

    # Mean: dashed line
    geom_line(
      aes(y = mean, colour = "Mean", linetype = "Mean"),
      linewidth = 0.7,
      na.rm = TRUE
    ) +

    # Pharmacy First launch
    geom_vline(
      xintercept = PF_start,
      linetype = "dashed",
      linewidth = 0.5,
      colour = "blue"
    ) +

    # GP Connect introduction
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

  if (nrow(d) == 0) {
    stop(
      "No complete annual comparisons for: ",
      cond, " / ", setting
    )
  }

  wide <- d %>%
    mutate(year = as.character(year)) %>%
    select(practice, year, annual_rate) %>%
    pivot_wider(
      names_from = year,
      values_from = annual_rate
    ) %>%
    filter(
      !is.na(`Year 1`),
      !is.na(`Year 2`)
    )

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

  # Use the same practices in the plot and annotation.
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

    # Connect each practice's two annual observations.
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

    plot_layout(
      widths = c(2.4, 1)
    ) +

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
        "Annual comparisons include practices with 12 valid months ",
        "in each year and monthly denominators >= ",
        min_denom, "."
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

# 10. Generate and save one figure per condition and setting ------------------

practice_figs <- rates_practice %>%
  distinct(condition, Setting) %>%
  arrange(condition, Setting)

pwalk(
  practice_figs,
  function(condition, Setting) {

    message(
      "Generating figure: ",
      condition, " / ", Setting
    )

    p <- plot_practice_figure(
      condition,
      Setting
    )

    file_stub <- str_replace_all(
      tolower(condition),
      "[^a-z0-9]+",
      "_"
    )

    output_file <- here(
      "output",
      paste0(
        "practice_rate_",
        tolower(Setting),
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
)

# 11. Display an example figure -----------------------------------------------

print(
  plot_practice_figure(
    "All PF conditions",
    "PF"
  )
)

# 12. Final quality checks -----------------------------------------------------

cat("\n========== QUALITY CHECKS ==========\n")

cat(
  "Number of practice-month observations:",
  nrow(rates_practice),
  "\n"
)

cat(
  "Number of practices:",
  n_distinct(rates_practice$practice),
  "\n"
)

cat(
  "Number of monthly summary rows:",
  nrow(rates_practice_summary),
  "\n"
)

cat(
  "Number of complete annual comparison rows:",
  nrow(rates_practice_year),
  "\n"
)

cat(
  "Number of figures generated:",
  nrow(practice_figs),
  "\n"
)

cat("\nFigures and CSV files saved in:\n")
cat(here("output"), "\n")
