# ZERO vs NON-ZERO NUMERATOR ANALYSIS
# Monthly and annual practice-level analysis
# Statistical Disclosure Control (SDC) - OpenSAFELY guidance
#
# SDC rules (all settings, all dates; same as the other scripts):
#   1. A practice count of 1-7 in EITHER category (zero / non-zero) redacts
#      BOTH categories, so neither can be recovered from the other.
#      Zero counts are retained.
#   2. All remaining practice counts are rounded to the nearest 5.
#   3. Total practices = sum of the ROUNDED counts (as the guidance requires),
#      and percentages are calculated only from the rounded counts.
#   4. Plots and CSVs use the protected values only.
#
# Graphs: one monthly and one annual figure per condition, faceted by setting.

# 1. Packages

library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(lubridate)
library(here)
library(scales)
library(stringr)

# 2. SDC parameters

SDC_THRESHOLD <- 7          # counts <= 7 are redacted
SDC_BASE <- 5               # remaining counts rounded to the nearest 5
REDACTED <- "[REDACTED]"

PF_start_date <- as.Date("2024-02-01")
GP_connect_date <- as.Date("2025-10-01")

sdc_count <- function(x, threshold = SDC_THRESHOLD, base = SDC_BASE) {
  case_when(
    is.na(x) ~ NA_real_,
    x == 0 ~ 0,
    x <= threshold ~ NA_real_,
    TRUE ~ round(x / base) * base
  )
}

sdc_small <- function(x, threshold = SDC_THRESHOLD) {
  !is.na(x) & x > 0 & x <= threshold
}

condition_labels <- c(
  uti = "UTI",
  sinusitis = "Sinusitis",
  otitis_media = "Otitis media",
  sore_throat = "Sore throat",
  impetigo = "Impetigo",
  insect_bite = "Insect bites",
  shingles = "Shingles",
  acutebronchitis_control = "Acute bronchitis (control)",
  conjunctivitisallergic_control = "Allergic conjunctivitis (control)",
  vulvovaginalcandidiasis_control = "Vulvovaginal candidiasis (control)",
  all_conditions = "All PF conditions"
)

# 3. Read and prepare data

measures_new_approach_consultation_and_medication <- read_csv(
  here("output", "measures_new_approach_consultation_and_medication.csv"),
  show_col_types = FALSE
)

data <- measures_new_approach_consultation_and_medication %>%
  filter(
    grepl("^(gp|pf)_medication_", measure)
  ) %>%
  mutate(
    interval_start = as.Date(interval_start),
    interval_end   = as.Date(interval_end),
    month          = floor_date(interval_start, "month"),
    year           = year(interval_start),

    # Extract setting
    setting = case_when(
      grepl("^gp_", measure) ~ "GP",
      grepl("^pf_", measure) ~ "PF",
      TRUE ~ NA_character_
    ),

    # Extract condition
    condition = case_when(
      grepl("_all_conditions$", measure) ~ "all_conditions",
      grepl("_uti$", measure) ~ "uti",
      grepl("_sinusitis$", measure) ~ "sinusitis",
      grepl("_otitismedia$", measure) ~ "otitis_media",
      grepl("_sorethroat$", measure) ~ "sore_throat",
      grepl("_impetigo$", measure) ~ "impetigo",
      grepl("_insectbite$", measure) ~ "insect_bite",
      grepl("_shingles$", measure) ~ "shingles",
      grepl("_acutebronchitis_control$", measure) ~ "acutebronchitis_control",
      grepl("_conjunctivitisallergic_control$", measure) ~ "conjunctivitisallergic_control",
      grepl("_vulvovaginalcandidiasis_control$", measure) ~ "vulvovaginalcandidiasis_control",
      TRUE ~ NA_character_
    ),

    # Convert to factors
    setting = factor(setting, levels = c("GP", "PF")),
    condition = factor(condition, levels = names(condition_labels))
  )

# Check extracted variables (row counts only, no patient counts)
print(data %>% count(setting, condition), n = Inf)

# Check unmatched measures
print(data %>% filter(is.na(condition)) %>% count(measure), n = Inf)

data <- data %>%
  filter(!is.na(setting), !is.na(condition))

# 4. Monthly practice-level classification

monthly_practice <- data %>%
  group_by(setting, condition, measure, practice, month, year) %>%
  summarise(
    numerator = if (all(is.na(numerator))) NA_real_ else sum(numerator, na.rm = TRUE),
    denominator = if (all(is.na(denominator))) NA_real_ else sum(denominator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    zero = if_else(is.na(numerator), NA_integer_, as.integer(numerator == 0)),
    non_zero = if_else(is.na(numerator), NA_integer_, as.integer(numerator > 0)),
    numerator_status = case_when(
      is.na(numerator) ~ NA_character_,
      numerator == 0 ~ "zero",
      numerator > 0 ~ "non_zero"
    )
  )

# 5. Monthly summary (raw practice counts; never written out)

monthly_summary <- monthly_practice %>%
  filter(!is.na(numerator_status)) %>%
  group_by(setting, condition, measure, month) %>%
  summarise(
    zero_count = sum(zero),
    non_zero_count = sum(non_zero),
    .groups = "drop"
  ) %>%
  arrange(setting, condition, month)

# 6. Annual practice-level classification
# Annual numerator is the sum of monthly numerators for each practice.
# A practice is classified as zero only if its annual numerator is zero.

annual_practice <- monthly_practice %>%
  group_by(setting, condition, measure, practice, year) %>%
  summarise(
    numerator = if (all(is.na(numerator))) NA_real_ else sum(numerator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    zero = if_else(is.na(numerator), NA_integer_, as.integer(numerator == 0)),
    non_zero = if_else(is.na(numerator), NA_integer_, as.integer(numerator > 0)),
    numerator_status = case_when(
      is.na(numerator) ~ NA_character_,
      numerator == 0 ~ "zero",
      numerator > 0 ~ "non_zero"
    )
  )

# 7. Annual summary (raw practice counts; never written out)

months_per_year <- monthly_summary %>%
  mutate(year = year(month)) %>%
  group_by(setting, condition, measure, year) %>%
  summarise(months_observed = n_distinct(month), .groups = "drop")

annual_summary <- annual_practice %>%
  filter(!is.na(numerator_status)) %>%
  group_by(setting, condition, measure, year) %>%
  summarise(
    zero_count = sum(zero),
    non_zero_count = sum(non_zero),
    .groups = "drop"
  ) %>%
  left_join(months_per_year, by = c("setting", "condition", "measure", "year")) %>%
  arrange(setting, condition, year)

# 8. SDC function

apply_sdc <- function(df) {
  df %>%
    mutate(
      # If either category has 1-7 practices, suppress BOTH
      suppress_cell = sdc_small(zero_count) | sdc_small(non_zero_count),

      zero_count_sdc = if_else(suppress_cell, NA_real_, sdc_count(zero_count)),
      non_zero_count_sdc = if_else(suppress_cell, NA_real_, sdc_count(non_zero_count)),

      # Total = sum of rounded counts
      total_practices_sdc = zero_count_sdc + non_zero_count_sdc,

      # Percentages from rounded counts only
      zero_percentage_sdc = if_else(
        !is.na(total_practices_sdc) & total_practices_sdc > 0,
        100 * zero_count_sdc / total_practices_sdc,
        NA_real_
      ),
      non_zero_percentage_sdc = if_else(
        !is.na(total_practices_sdc) & total_practices_sdc > 0,
        100 * non_zero_count_sdc / total_practices_sdc,
        NA_real_
      )
    )
}

as_release <- function(x, suppressed) {
  if_else(suppressed, REDACTED, as.character(x))
}

# 9. Apply SDC to monthly results

monthly_sdc <- apply_sdc(monthly_summary)

monthly_export <- monthly_sdc %>%
  transmute(
    setting,
    condition,
    measure,
    month,
    zero_count = as_release(zero_count_sdc, suppress_cell),
    non_zero_count = as_release(non_zero_count_sdc, suppress_cell),
    total_practices = as_release(total_practices_sdc, suppress_cell),
    zero_percentage = round(zero_percentage_sdc, 1),
    non_zero_percentage = round(non_zero_percentage_sdc, 1)
  )

# 10. Apply SDC to annual results

annual_sdc <- apply_sdc(annual_summary)

annual_export <- annual_sdc %>%
  transmute(
    setting,
    condition,
    measure,
    year,
    months_observed,
    zero_count = as_release(zero_count_sdc, suppress_cell),
    non_zero_count = as_release(non_zero_count_sdc, suppress_cell),
    total_practices = as_release(total_practices_sdc, suppress_cell),
    zero_percentage = round(zero_percentage_sdc, 1),
    non_zero_percentage = round(non_zero_percentage_sdc, 1)
  )

# 11. Plotting data (protected percentages only)

to_long <- function(df, time_var) {
  df %>%
    select(
      setting,
      condition,
      {{ time_var }},
      zero_percentage = zero_percentage_sdc,
      non_zero_percentage = non_zero_percentage_sdc
    ) %>%
    pivot_longer(
      cols = c(zero_percentage, non_zero_percentage),
      names_to = "status",
      values_to = "percentage"
    ) %>%
    mutate(
      status = factor(
        recode(status, zero_percentage = "Zero", non_zero_percentage = "Non-zero"),
        levels = c("Zero", "Non-zero")
      )
    )
}

monthly_plot_data <- to_long(monthly_sdc, month)
annual_plot_data  <- to_long(annual_sdc, year)

status_colours <- c(Zero = "#be6363", `Non-zero` = "#2cb89e")

# Intervention dates as decimal years for the annual x-axis
PF_start_year   <- year(PF_start_date) + (month(PF_start_date) - 1) / 12
GP_connect_year <- year(GP_connect_date) + (month(GP_connect_date) - 1) / 12

theme_zero <- theme_bw() +
  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(size = 10, face = "bold"),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

# 12. Monthly plot for one condition (facet by setting)

plot_monthly <- function(cond) {
  ggplot(
    filter(monthly_plot_data, condition == cond),
    aes(x = month, y = percentage, fill = status)
  ) +
    geom_col(position = "stack", width = 25, na.rm = TRUE) +
    geom_vline(xintercept = PF_start_date, linetype = "dashed",
               colour = "blue", linewidth = 0.7) +
    geom_vline(xintercept = GP_connect_date, linetype = "dashed",
               colour = "red", linewidth = 0.7) +
    facet_wrap(~ setting, ncol = 1) +
    scale_fill_manual(values = status_colours, name = "Numerator status") +
    scale_y_continuous(
      breaks = seq(0, 100, 20),
      labels = label_percent(scale = 1),
      expand = expansion(mult = c(0, 0.02))
    ) +
    coord_cartesian(ylim = c(0, 100)) +
    scale_x_date(date_breaks = "2 months", date_labels = "%Y-%m") +
    labs(
      title = paste0(
        "Monthly distribution of practices by numerator status: ",
        condition_labels[[cond]]
      ),
      subtitle = "Zero versus non-zero numerators; SDC applied to GP and PF measures",
      caption = paste(
        "Practice counts 1-7 redacted (both categories); others rounded to the nearest 5.",
        "Redacted months appear as gaps.",
        "Blue dashed line: Pharmacy First launch; red dashed line: GP Connect."
      ),
      x = "Month",
      y = "Percentage of practices"
    ) +
    theme_zero +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

# 13. Annual plot for one condition (facet by setting)

plot_annual <- function(cond) {
  ggplot(
    filter(annual_plot_data, condition == cond),
    aes(x = year, y = percentage, colour = status, group = status)
  ) +
    geom_line(linewidth = 0.8, na.rm = TRUE) +
    geom_point(size = 2, na.rm = TRUE) +
    geom_vline(xintercept = PF_start_year, linetype = "dashed",
               colour = "blue", linewidth = 0.7) +
    geom_vline(xintercept = GP_connect_year, linetype = "dashed",
               colour = "red", linewidth = 0.7) +
    facet_wrap(~ setting, ncol = 1) +
    scale_colour_manual(values = status_colours, name = "Numerator status") +
    scale_y_continuous(
      breaks = seq(0, 100, 20),
      labels = label_percent(scale = 1)
    ) +
    coord_cartesian(ylim = c(0, 100)) +
    scale_x_continuous(breaks = pretty_breaks()) +
    labs(
      title = paste0(
        "Annual distribution of practices by numerator status: ",
        condition_labels[[cond]]
      ),
      subtitle = "Zero versus non-zero annual numerators; SDC applied to GP and PF measures",
      caption = paste(
        "Practice counts 1-7 redacted (both categories); others rounded to the nearest 5.",
        "Partial years: see months_observed in the annual CSV.",
        "Blue dashed line: Pharmacy First launch; red dashed line: GP Connect."
      ),
      x = "Year",
      y = "Percentage of practices"
    ) +
    theme_zero
}

# 14. Output directory

output_folder <- here("output", "zero_counts")
dir.create(output_folder, recursive = TRUE, showWarnings = FALSE)

# 15. Export SDC-controlled CSV files (underlying data for all figures)

write_csv(
  monthly_export,
  file.path(output_folder, "monthly_zero_nonzero_summary_SDC.csv")
)

write_csv(
  annual_export,
  file.path(output_folder, "annual_zero_nonzero_summary_SDC.csv")
)

# 16. One monthly and one annual PNG per condition

conditions_present <- levels(droplevels(monthly_sdc$condition))

for (cond in conditions_present) {

  message("Generating figures: ", cond)

  ggsave(
    filename = file.path(output_folder, paste0("monthly_zero_nonzero_", cond, "_SDC.png")),
    plot = plot_monthly(cond),
    width = 12,
    height = 7,
    dpi = 300
  )

  ggsave(
    filename = file.path(output_folder, paste0("annual_zero_nonzero_", cond, "_SDC.png")),
    plot = plot_annual(cond),
    width = 8,
    height = 7,
    dpi = 300
  )
}

# 17. SDC summary and completion message

cat("\nZERO / NON-ZERO ANALYSIS COMPLETED\n")
cat("\nSDC: practice counts <=", SDC_THRESHOLD, "redacted;",
    "others rounded to nearest", SDC_BASE, "(all settings, all dates)\n")

cat("\nMonthly suppressed cells:", sum(monthly_sdc$suppress_cell), "\n")
cat("Annual suppressed cells:", sum(annual_sdc$suppress_cell), "\n")

cat("\nConditions plotted:", length(conditions_present), "\n")
cat("Output directory:", output_folder, "\n")

stopifnot(
  all(monthly_sdc$zero_count_sdc %% SDC_BASE == 0, na.rm = TRUE),
  all(monthly_sdc$non_zero_count_sdc %% SDC_BASE == 0, na.rm = TRUE),
  all(annual_sdc$zero_count_sdc %% SDC_BASE == 0, na.rm = TRUE),
  all(annual_sdc$non_zero_count_sdc %% SDC_BASE == 0, na.rm = TRUE)
)