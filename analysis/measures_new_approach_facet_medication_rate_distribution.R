# ------------------------------------------------------------------------------
# PRACTICE-LEVEL PRESCRIBING RATE ANALYSIS
#
# Graph A:
#   Monthly median (solid line), mean (dashed line), and IQR (shaded area)
#   across GP practices.
#
# Graph B:
# Year 1 versus Year 2 annual prescribing rates for each practice.
#
# Year 1: February 2024 to January 2025
# Year 2: February 2025 to January 2026
#
# Annual rate:
#   Sum of monthly numerators / mean monthly denominator * 1,000
#
# Eligibility rules (note: these differ by design):
#   - Monthly (Graph A): a practice-month rate is calculated only when that
#     month's denominator >= min_denom.
#   - Annual (Graph B): a practice-year rate is calculated only when the
#     practice has 12 months of data in that year AND its MEAN monthly
#     denominator >= min_denom. A practice can therefore contribute to
#     Graph A in some months but not to Graph B, or vice versa.
#
# Disclosure control:
#   - Monthly summary statistics are suppressed when fewer than
#     min_practices practices contribute.
#   - All released practice counts (CSV and figure labels) are rounded
#     using OpenSAFELY midpoint-6 rounding.
#   - Detailed practice-level CSVs are not written to output.
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

#2. Settings-----------------------------------------------------------------
practice_var <- "practice"
min_denom <- 100       # This helps for SDC 
min_practices <- 10    # minimum contributing practices for a monthly summary

#Pharmacy First launch
PF_start <- as.Date("2024-02-01")

#Year boundaries
year2_start <- as.Date("2025-02-01")
year2_end <- as.Date("2026-02-01")   # exclusive upper bound

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

#Output directory
#output_dir <- here("output")
output_dir <- here("output", "practice_level_change")
dir.create(
 output_dir,
 recursive = TRUE,
  showWarnings = FALSE
  )
# Disclosure helper: OpenSAFELY midpoint-6 rounding.
# Values 1-6 become 3, 7-12 become 9, etc.; 0 stays 0.
roundmid_any <- function(x, to = 6) {
  ifelse(
    is.na(x),
    NA_real_,
    ceiling(x / to) * to - (floor(to / 2) * (x != 0))
  )
}

#3. Read and validate input data ---------------------------------------------

input_file <- here(
  "output",  
  "measures_new_approach_consultation_and_medication.csv"
  )

if (!file.exists(input_file)) {
 stop("Input file not found: ", input_file)
}

#raw_data <- read_csv(input_file,show_col_types = FALSE)

raw_data <- read_csv(input_file, show_col_types = FALSE) %>%
  mutate(interval_start = as.Date(interval_start)) %>%
  filter(
    interval_start >= as.Date("2024-02-01"),  # i just want the PF period
    interval_start < as.Date("2026-02-01")
  )

#raw_data <- read_csv("C:/Users/arnau/Downloads/measures_new_approach_consultation_and_medication (2).csv")

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

# Data coverage check: both years need 12 months for Graph B.
min_month <- min(raw_data$interval_start)
max_month <- max(raw_data$interval_start)
last_required_month <- seq(year2_end, by = "-1 month", length.out = 2)[2]

message("Data coverage: ", min_month, " to ", max_month)

if (min_month > PF_start) {
  warning(
    "Data start (", min_month, ") is after Year 1 start (", PF_start, "). ",
    "No practice will have 12 months in Year 1."
  )
}

if (max_month < last_required_month) {
  warning(
    "Data end (", max_month, ") is before the last month of Year 2 (",
    last_required_month, "). ",
    "No practice will have 12 months in Year 2, so Graph B panels ",
    "will show placeholders."
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

safe_quantile <- function(x, p) {
  if (all(is.na(x))) NA_real_ else as.numeric(quantile(x, p, na.rm = TRUE))
}

rates_practice_summary <- rates_practice %>%
  group_by(interval_start, Setting, condition) %>%
  summarise(
    n_practices = sum(!is.na(prescribing_rate)),
    median = safe_quantile(prescribing_rate, 0.50),
    mean = if (all(is.na(prescribing_rate))) {
      NA_real_
    } else {
      mean(prescribing_rate, na.rm = TRUE)
    },
    q1 = safe_quantile(prescribing_rate, 0.25),
    q3 = safe_quantile(prescribing_rate, 0.75),
    .groups = "drop"
  ) %>%
  # Suppress summaries based on too few practices.
  mutate(
    suppressed = n_practices < min_practices,
    across(
      c(median, mean, q1, q3),
      ~ if_else(suppressed, NA_real_, .x)
    )
  )

n_suppressed_months <- sum(rates_practice_summary$suppressed)
if (n_suppressed_months > 0) {
  message(
    "Monthly summaries suppressed (< ", min_practices, " practices): ",
    n_suppressed_months
  )
}

# Released version: rounded counts, suppression flag kept for transparency.
rates_practice_summary_release <- rates_practice_summary %>%
  mutate(n_practices = roundmid_any(n_practices))

write_csv(
  rates_practice_summary_release,
  file.path(output_dir, "practice_rate_monthly_summary.csv")
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
    mean_denominator = mean(denominator, na.rm = TRUE),
    annual_numerator = sum(numerator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    annual_rate = if_else(
      n_months == 12 & mean_denominator >= min_denom,
      1000 * annual_numerator / mean_denominator,
      NA_real_
    )
  )

# Diagnostic table: inspect missing months and denominator eligibility.
annual_diagnostics <- rates_practice_annual_all %>%
  group_by(Setting, condition, year) %>%
  summarise(
    practices_with_data = n_distinct(practice),
    practices_with_12_months = n_distinct(practice[n_months == 12]),
    practices_with_mean_denominator_100_or_more = n_distinct(
      practice[mean_denominator >= min_denom]
    ),
    practices_meeting_both_criteria = n_distinct(
      practice[n_months == 12 & mean_denominator >= min_denom]
    ),
    .groups = "drop"
  )

message("\nAnnual eligibility diagnostics (unrounded, log only):")
print(annual_diagnostics, n = Inf)

# Released version: rounded counts.
annual_diagnostics_release <- annual_diagnostics %>%
  mutate(across(starts_with("practices_"), roundmid_any))

write_csv(
  annual_diagnostics_release,
  file.path(output_dir, "practice_rate_annual_diagnostics.csv")
)


# Keep only practice-years that meet the annual eligibility criteria.
rates_practice_annual_eligible <- rates_practice_annual_all %>%
  filter(!is.na(annual_rate))

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

# Aggregated annual summary only; do not export practice-level rows.
annual_summary <- rates_practice_year %>%
  group_by(Setting, condition, year) %>%
  summarise(
    n_practices = n_distinct(practice),
    median_annual_rate = median(annual_rate, na.rm = TRUE),
    mean_annual_rate = mean(annual_rate, na.rm = TRUE),
    q1_annual_rate = as.numeric(quantile(annual_rate, 0.25, na.rm = TRUE)),
    q3_annual_rate = as.numeric(quantile(annual_rate, 0.75, na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  mutate(
    suppressed = n_practices < min_practices,
    across(
      c(median_annual_rate, mean_annual_rate, q1_annual_rate, q3_annual_rate),
      ~ if_else(suppressed, NA_real_, .x)
    ),
    n_practices = roundmid_any(n_practices)
  )

write_csv(
  annual_summary,
  file.path(output_dir, "practice_rate_annual_summary.csv")
)


# 7. Graph A: monthly prescribing trend ---------------------------------------

empty_panel <- function(label, title) {
  ggplot() +
    annotate("text", x = 1, y = 1, label = label, size = 3.5) +
    xlim(0, 2) +
    ylim(0, 2) +
    labs(title = title, x = NULL, y = NULL) +
    theme_void()
}

plot_practice_trend <- function(cond, setting) {
  
  d <- rates_practice_summary %>%
    filter(
      condition == cond,
      Setting == setting
    )
  
  if (nrow(d) == 0 || all(is.na(d$median))) {
    return(
      empty_panel(
        paste0("No releasable monthly summary data\n", cond, " / ", setting),
        paste("Monthly trend:", cond, "/", setting)
      )
    )
  }
  
  ggplot(d, aes(x = interval_start)) +
    
    geom_ribbon(
      aes(ymin = q1, ymax = q3),
      fill = "#90a8c2",
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
      linewidth = 0.2,
      colour = "blue"
    ) +
    
    geom_vline(
      xintercept = GP_connect,
      linetype = "dashed",
      linewidth = 0.2,
      colour = "black"
    ) +
    
    scale_colour_manual(
      values = c(Median = "#2C4A6E", Mean = "#C0392B"),
      name = NULL
    ) +
    
    scale_linetype_manual(
      values = c(Median = "solid", Mean = "dashed"),
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
      title = paste0("Monthly ", setting, " prescribing across GP practices"),
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
      axis.text.x = element_text(angle = 45, hjust = 1),
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
    return(
      empty_panel(
        paste0(
          "No complete annual comparisons\n",
          cond, " / ", setting,
          "\nCheck annual eligibility diagnostics"
        ),
        "Change across GP practices"
      )
    )
  }
  
  wide <- d %>%
    select(practice, year, annual_rate) %>%
    pivot_wider(
      names_from = year,
      values_from = annual_rate
    )
  
  if (!"Year 1" %in% names(wide)) wide[["Year 1"]] <- NA_real_
  if (!"Year 2" %in% names(wide)) wide[["Year 2"]] <- NA_real_
  
  wide <- wide %>%
    filter(!is.na(`Year 1`), !is.na(`Year 2`))
  
  if (nrow(wide) < min_practices) {
    return(
      empty_panel(
        paste0(
          "Fewer than ", min_practices,
          " practices with both years\n",
          cond, " / ", setting
        ),
        "Change across GP practices"
      )
    )
  }
  
  n_up <- sum(wide$`Year 2` > wide$`Year 1`)
  n_down <- sum(wide$`Year 2` < wide$`Year 1`)
  n_same <- sum(wide$`Year 2` == wide$`Year 1`)
  n_tot <- nrow(wide)
  
  # Rounded counts for release.
  lab <- paste0(
    "Practices: ", roundmid_any(n_tot),
    "\nIncreased: ", roundmid_any(n_up),
    " | Decreased: ", roundmid_any(n_down),
    " | Unchanged: ", roundmid_any(n_same),
    "\n(counts rounded, midpoint 6)"
  )
  
  d_plot <- d %>%
    filter(practice %in% wide$practice) %>%
    mutate(year = factor(year, levels = c("Year 1", "Year 2")))
  
  ggplot(
    d_plot,
    aes(x = year, y = annual_rate, group = practice)
  ) +
    
    geom_line(
      colour = "grey65",
      alpha = 0.3,
      linewidth = 0.25
    ) +
    
    geom_point(
      data = filter(d_plot, year == "Year 1"),
      colour = "#ea0b1a",
      size = 1.1,
      alpha = 0.65
    ) +
    
    geom_point(
      data = filter(d_plot, year == "Year 2"),
      colour = "#c222e6",
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
      expand = expansion(mult = c(0.02, 0.22))
    ) +
    
    labs(
      title = "Change across GP practices",
      subtitle = "Red circle = 2024; Purple triangle = 2025",
      x = NULL,
      y = "Prescribing rate per 1,000 average eligible population"
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
      title = paste0(cond, ": ", setting, " prescribing rates by GP practice"),
      caption = paste0(
        "Year 1 = Feb 2024 to Jan 2025; Year 2 = Feb 2025 to Jan 2026. ",
        "Blue dashed line = Pharmacy First launch; ",
        "black dashed line = GP Connect introduction.\n",
        "Monthly rates require that month's denominator >= ", min_denom,
        "; monthly summaries shown only when >= ", min_practices,
        " practices contribute. ",
        "Comparisons require 12 months in each year ",
        "and mean monthly denominator >= ", min_denom, "."
      ),
      theme = theme(
        plot.title = element_text(face = "bold", size = 14),
        plot.caption = element_text(size = 8, hjust = 0)
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
  
  message("Generating figure: ", cond, " / ", setting)
  
  p <- plot_practice_figure(cond, setting)
  
  file_stub <- str_replace_all(tolower(cond), "[^a-z0-9]+", "_")
  
  #output_file <- here(
   # "output",
   # paste0("practice_rate_", tolower(setting), "_", file_stub, ".png")
  #)

output_file <- here(
  "output",
  "practice_level_change",
  paste0("practice_rate_", tolower(setting), "_", file_stub, ".png")
  )
#
  
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

practices_both_years_by_group <- rates_practice_year %>%
  group_by(Setting, condition) %>%
  summarise(
    practices_with_both_years = n_distinct(practice),
    .groups = "drop"
  )

cat("\n------------ QUALITY CHECKS--------------------------\n")
cat("Data coverage:", format(min_month), "to", format(max_month), "\n")
cat("Practice-month observations:", nrow(rates_practice), "\n")
cat("Distinct practices:", n_distinct(rates_practice$practice), "\n")
cat("Monthly summary rows:", nrow(rates_practice_summary), "\n")
cat(
  "Monthly summaries suppressed (<", min_practices, "practices):",
  n_suppressed_months, "\n"
)
cat("Eligible practice-year rows:", nrow(rates_practice_annual_eligible), "\n")
cat(
  "Distinct practices with both years (any setting/condition):",
  n_distinct(rates_practice_year$practice), "\n"
)
cat("Number of condition-setting figures:", nrow(practice_figs), "\n")

cat("\nPractices with both years, by setting and condition:\n")
print(practices_both_years_by_group, n = Inf)

cat("\nAggregated output files saved in:\n")
cat(output_dir, "\n")

cat("\nAnnual eligibility diagnostics (unrounded, log only):\n")
print(annual_diagnostics, n = Inf)
